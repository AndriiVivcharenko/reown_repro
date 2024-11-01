import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/appkit_modal.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

const WC_PROJECT_ID = 'bfc0c865817b858fabef308705f8e546';

void main() async {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  static int nowPlusThreeHours() =>
      DateTime.now()
          .add(
            const Duration(
              hours: 3,
            ),
          )
          .millisecondsSinceEpoch ~/
      1000;

  @override
  void initState() {
    super.initState();

    _setProviderStatesFromPersistedState();
  }

  Future<void> _cleanSession() async {
    print("cleaning session ${StackTrace.current}");
    final storage = await SharedPreferences.getInstance();
    final wcService = ref.read(w3mServiceProvider);

    storage.remove('session');
    storage.remove('walletType');
    storage.remove('userSession');
    wcService?.disconnect();
    // await BackendAuth.initGuestSession().timeout(const Duration(
    //   seconds: 8,
    // ));
  }

  Future<void> _setProviderStatesFromPersistedState() async {
    try {
      await Future.wait(
        [
          initWcClient(ref, context),
          // setupWeb3Auth(),
        ],
      );
    } catch (e, s) {
      print(e);
      print(s);
      // await Sentry.captureException(
      //   e,
      //   stackTrace: s,
      // );
      // FlutterNativeSplash.remove();
    }

    final storage = await SharedPreferences.getInstance();

    try {
      final wcService = ref.read(w3mServiceProvider);

      final storedWcSession = storage.getString('session');

      //check if a session is stored
      if (storedWcSession == null) {
        _cleanSession();
        throw Exception('No session stored');
      }

      final wcSession =
          ReownAppKitModalSession.fromMap(jsonDecode(storedWcSession));

      if ((wcSession.expiry ?? 0) <= nowPlusThreeHours()
          // && backendSession.expire ?? 0 <= nowPlusThreeHours()
          ) {
        _cleanSession();
        throw Exception('Session expired');
      }

      ref.read(wcSessionProvider.notifier).state = wcSession;
      // ref.read(walletTypeProvider.notifier).state = walletType;
      // ref.read(userSessionProvider.notifier).state = backendSession;
      // Backend.recreateServices(backendSession.jwt.raw);
      // ref.read(websocketProvider.notifier).init();
    } catch (e, st) {
      // Sentry.captureException(
      //   e,
      //   stackTrace: st,
      // );
      _cleanSession();
    } finally {
      // FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(wcSessionProvider);
    final w3mService = ref.watch(w3mServiceProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (w3mService != null)
              AppKitModalConnectButton(
                appKit: w3mService,
              )
          ],
        ),
      ),
    );
  }
}

final w3mServiceProvider = StateProvider<ReownAppKitModal?>((ref) {
  return null;
});

final wcSessionProvider = StateProvider<ReownAppKitModalSession?>((ref) {
  return null;
});

Future<ReownAppKitModal> initWcClient(
    WidgetRef ref, BuildContext context) async {
  //create Web3Modal service and set provider
  final ReownAppKitModal w3mService = ReownAppKitModal(
    context: context,
    projectId: WC_PROJECT_ID,
    metadata: const PairingMetadata(
        name: 'Test',
        description: 'Test - Test',
        url: 'https://www.google.com',
        icons: ['https://avatars.githubusercontent.com/u/116345848'],
        redirect: Redirect(
          native: 'io.andriivivcharenko.reown.session.reownRepro://',
        )),
  );

  w3mService.onSessionEventEvent.subscribe(wrapOnSessionEvent(ref));
  w3mService.onModalConnect.subscribe(wrapOnSessionConnect(ref, context));
  w3mService.onModalDisconnect.subscribe(wrapOnSessionDisconnect(ref));
  w3mService.onSessionExpireEvent.subscribe(wrapOnSessionExpire(ref));

  await w3mService.init();
  ref.read(w3mServiceProvider.notifier).state = w3mService;

  return w3mService;
}

void Function(ModalConnect?) wrapOnSessionConnect(
    WidgetRef ref, BuildContext context) {
  return (ModalConnect? args) {
    //set session and wallet type provider
    ref.read(wcSessionProvider.notifier).state = args?.session;

    //store session and wallet type
    final storage = SharedPreferences.getInstance();
    final session = jsonEncode(args?.session.toMap());
    storage.then((s) {
      s.setString('session', session);
      print(s);
    });
  };
}

void Function(ModalDisconnect?) wrapOnSessionDisconnect(WidgetRef ref) {
  return (ModalDisconnect? args) {
    onSessionDisconnect(args, ref);
  };
}

void Function(SessionExpire?) wrapOnSessionExpire(WidgetRef ref) {
  return (SessionExpire? event) {
    if (event?.topic != null) {
      onSessionDisconnect(
        ModalDisconnect(
          topic: event!.topic,
        ),
        ref,
      );
    }
  };
}

void Function(SessionEvent?) wrapOnSessionEvent(WidgetRef ref) {
  return (SessionEvent? args) {
    // talker.log('Session event: ${args?.chainId}');
  };
}

void onSessionDisconnect(ModalDisconnect? args, WidgetRef ref) {
  //remove session and wallet type
  final storage = SharedPreferences.getInstance();
  // storage.then((value) => value.remove('session'));
  // storage.then((value) => value.remove('walletType'));
  // storage.then((value) => value.remove('userSession'));

  ref.read(wcSessionProvider.notifier).state = null;
}
