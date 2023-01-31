import 'dart:async';
import 'package:alert/alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:serumswap/acount.dart';
import 'package:serumswap/home.dart';
import 'package:serumswap/orderbook.dart';
import 'package:serumswap/phantom.dart';
import 'package:serumswap/providers/wallet_state_provider.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solana/solana.dart';
import 'dart:convert';
import 'package:http/http.dart';

void main() {
  runApp(MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(),
      debugShowCheckedModeBanner: false,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => WalletStateProvider()),
        ],
        child: const MyApp(),
      )));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription sub;

  late Phantom phantom;

  var data_feed = {};

  int selected = 0;

  dynamic screens;
  @override
  void initState() {
    setState(() {
      phantom = Phantom();
      screens = [
        Home(
          phantom: phantom,
        ),
        const Orderbook(),
        Account(
          phantom: phantom,
        )
      ];
    });

    super.initState();
    handleIncomingLinks(context);
  }

  void handleIncomingLinks(context) async {
    final provider = Provider.of<WalletStateProvider>(context, listen: false);
    sub = uriLinkStream.listen((Uri? link) async {
      Map<String, String> params = link?.queryParameters ?? {};

      if (params.containsKey("errorCode")) {
        Alert(message: params["errorMessage"].toString());
      } else {
        switch (link?.path) {
          case '/connect':
            if (phantom.phantomConnect.createSession(params)) {
              // connected = true;
              setState(() {
                provider.updateConnection(true);
              });
              Alert(message: "phantom Connected", shortDuration: true).show();
            } else {}
            break;
          case '/disconnect':
            setState(() {
              provider.updateConnection(false);
            });
            break;
          case '/signAndSendTransaction':
            var data = phantom.phantomConnect
                .decryptPayload(data: params["data"]!, nonce: params["nonce"]!);
            String sig = await data['signature'];
            await Future.delayed(const Duration(seconds: 3));
            final feed = await get(
                    Uri.parse("https://public-api.solscan.io/transaction/$sig"))
                .then((value) => value.body);
            var stat = jsonDecode(feed) as Map;
            print(stat);
            if (stat['status'] == 'success') {
              phantom.tswap = 1;
              phantom.sigurl = "https://solscan.io/tx/$sig";
              QuickAlert.show(
                context: context,
                type: QuickAlertType.success,
                titleColor: Colors.white,
                text: 'swap Completed Successfully!',
                textColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 68, 90, 117),
                confirmBtnColor: Colors.blue,
                confirmBtnText: "view on Solscan",
                cancelBtnText: "close",
                confirmBtnTextStyle: const TextStyle(
                  fontSize: 13,
                ),
                showCancelBtn: true,
                onCancelBtnTap: () => Navigator.pop(context),
                onConfirmBtnTap: () async => await launchUrl(
                    Uri.parse(phantom.sigurl),
                    mode: LaunchMode.inAppWebView),
              );
            } else {
              phantom.nswap = 1;
              QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                titleColor: Colors.white,
                text: 'swap failed',
                textColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 68, 90, 117),
                confirmBtnColor: Colors.blue,
              );
            }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 25, 27, 31),
      body: screens[selected],
      bottomNavigationBar: nav(),
    );
  }

  BottomNavigationBar nav() {
    return BottomNavigationBar(
      backgroundColor: const Color.fromARGB(255, 8, 6, 6),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      iconSize: 28,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(FeatherIcons.repeat),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            FeatherIcons.bookOpen,
          ),
          label: 'Business',
        ),
        BottomNavigationBarItem(
          icon: Icon(FeatherIcons.user),
          label: 'Account',
        ),
        // BottomNavigationBarItem(
        //   icon: Icon(Icons.settings),
        //   label: 'Settings',
        // ),
      ],
      currentIndex: selected,
      selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
      unselectedItemColor: Colors.blueGrey,
      onTap: (value) {
        setState(() {
          selected = value;
        });
      },
    );
  }
}
