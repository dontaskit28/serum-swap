import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jupiter_aggregator/jupiter_aggregator.dart';
import 'package:alert/alert.dart';
import 'package:phantom_connect/phantom_connect.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class Phantom {
  late StreamSubscription sub;
  final mints = {
    'SOL': 'So11111111111111111111111111111111111111112',
    'USDC': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
    'USDT': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    'SRM': 'SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt',
    'BTC': '9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E',
    'ETH': '2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk'
  };
  var data_feed = {};
  bool connected = false;
  int tswap = 0;
  int nswap = 0;
  String sigurl = "";
  late double balance;
  late PhantomConnect phantomConnect;
  RpcClient client = RpcClient("https://api.mainnet-beta.solana.com");

  Phantom() {
    phantomConnect = PhantomConnect(
      appUrl: "https://solana.com",
      deepLink: "dapp://flutterbooksample.com",
    );
  }

  void setConnected(bool connect) {
    connected = connect;
  }

  void connect() async {
    try {
      Uri connectUrl = phantomConnect.generateConnectUri(
          cluster: 'mainnet-beta', redirect: '/connect');

      await launchUrl(connectUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Alert(message: e.toString());
    }
  }

  void send(String address, double amount) async {
    final transferIx = SystemInstruction.transfer(
      fundingAccount:
          Ed25519HDPublicKey.fromBase58(phantomConnect.userPublicKey),
      recipientAccount: Ed25519HDPublicKey.fromBase58(address),
      lamports: (amount * lamportsPerSol).floor(),
    );
    final message = Message.only(transferIx);
    final blockhash = await RpcClient('https://api.devnet.solana.com')
        .getRecentBlockhash()
        .then((b) => b.blockhash);
    final compiled = message.compile(recentBlockhash: blockhash);

    final tx = SignedTx(
      messageBytes: compiled.data,
      signatures: [
        Signature(
          List.filled(64, 0),
          publicKey:
              Ed25519HDPublicKey.fromBase58(phantomConnect.userPublicKey),
        )
      ],
    ).encode();

    var launchUri = phantomConnect.generateSignAndSendTransactionUri(
        transaction: tx, redirect: '/signAndSendTransaction');
    await launchUrl(
      launchUri,
      mode: LaunchMode.externalApplication,
    );
  }

  void disconnect() {
    Uri url = phantomConnect.generateDisconnectUri(redirect: '/disconnect');
    Future<void> launch() async {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    }

    launch();
  }

  Future swap(String inputmint, String outputmint, double amount) async {
    print(inputmint);
    print(outputmint);
    String? mint1 = mints[inputmint];
    String? mint2 = mints[outputmint];
    if (inputmint == 'USDC') {
      amount = amount * 1000000;
    }
    if (inputmint == 'SOL') {
      amount = amount * lamportsPerSol;
    }
    if (inputmint == outputmint) {
      Alert(message: "swap is not possible", shortDuration: true).show();
    } else {
      final client1 = JupiterAggregatorClient();
      final data = await client1.getQuote(
          inputMint: mint1.toString(),
          outputMint: mint2.toString(),
          amount: amount.toInt(),
          slippage: 50,
          feeBps: 4);
      final routes = [];
      data.forEach((element) {
        final d = element.toJson();
        print(d);
        routes.add(d);
      });
      final trans = await client1.getSwapTransactions(
          userPublicKey: phantomConnect.userPublicKey.toString(),
          route: data[0]);
      trans.toJson().forEach((key, value) async {
        //final transcation = SignedTx.decode(value).encode();
        if (value != null) {
          Uri tran = phantomConnect.generateSignAndSendTransactionUri(
              redirect: '/signAndSendTransaction', transaction: value);
          await launchUrl(tran, mode: LaunchMode.externalApplication);
        }
      });
    }
  }

  Future getBalance() async {
    final value = await client.getBalance(phantomConnect.userPublicKey);

    return value / lamportsPerSol;
  }

  Future airDrop() async {
    try {
      await client.requestAirdrop(
          phantomConnect.userPublicKey, 1 * lamportsPerSol);

      return true;
    } catch (E) {
      return false;
    }
  }
}
