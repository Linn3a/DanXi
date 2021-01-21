import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dan_xi/model/person.dart';
import 'package:dan_xi/page/card_detail.dart';
import 'package:dan_xi/page/card_traffic.dart';
import 'package:dan_xi/page/subpage_main.dart';
import 'package:dan_xi/repository/card_repository.dart';
import 'package:dan_xi/repository/qr_code_repository.dart';
import 'package:dan_xi/util/fdu_wifi_detection.dart';
import 'package:dan_xi/util/wifi_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_progress_dialog/flutter_progress_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

final QuickActions quickActions = QuickActions();

void main() {
  runApp(DanxiApp());
}

class DanxiApp extends StatelessWidget {
  final Map<String, Function> routes = {
    '/card/detail': (context, {arguments}) =>
        CardDetailPage(arguments: arguments),
    '/card/crowdData': (context, {arguments}) =>
        CardCrowdData(arguments: arguments)
  };

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "旦兮",
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: HomePage(title: "旦兮"),
      onGenerateRoute: (settings) {
        final String name = settings.name;
        final Function pageContentBuilder = this.routes[name];
        if (pageContentBuilder != null) {
          final Route route = MaterialPageRoute(
              builder: (context) =>
                  pageContentBuilder(context, arguments: settings.arguments));
          return route;
        }
        return null;
      },
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences _preferences;
  ValueNotifier<PersonInfo> _personInfo = ValueNotifier(null);
  ValueNotifier<String> _connectStatus = ValueNotifier("");
  StreamSubscription<ConnectivityResult> _connectivitySubscription;
  int _pageindex = 0;

  final List<Function> _subpageBuilders = [() => HomeSubpage()];

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _showQRCode() {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return new AlertDialog(
              title: Text("复活码"),
              content: Container(
                  width: double.maxFinite,
                  child: Center(
                      child: FutureBuilder<String>(
                          future: QRCodeRepository.getInstance()
                              .getQRCode(_personInfo.value),
                          builder: (BuildContext context,
                              AsyncSnapshot<String> snapshot) {
                            if (snapshot.hasData) {
                              return QrImage(data: snapshot.data, size: 200.0);
                            } else {
                              return Text("加载复活码中...\n(由于复旦校园服务器较差，可能需要5~10秒)");
                            }
                          }))));
        });
  }

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = WiFiUtils.getConnectivity()
        .onConnectivityChanged
        .listen((_) => {_loadNetworkState()});
    _loadSharedPreference();
    _loadNetworkState();
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
          type: 'action_qr_code', localizedTitle: '复活码', icon: 'ic_launcher'),
    ]);

    quickActions.initialize((shortcutType) {
      if (shortcutType == 'action_qr_code') {
        if (_personInfo != null) {
          _showQRCode();
        }
      }
    });
  }

  Future<void> _tryLogin(String id, String pwd) async {
    var progressDialog =
        showProgressDialog(loadingText: "尝试登录中...", context: context);
    var name = "";
    await CardRepository.getInstance().login(new PersonInfo(id, pwd, "")).then(
        (_) async => {
              progressDialog.dismiss(),
              _preferences.setString("id", id),
              _preferences.setString("password", pwd),
              name = await CardRepository.getInstance().getName(),
              _preferences.setString("name", name),
              setState(() {
                _personInfo.value = new PersonInfo(id, pwd, name);
              }),
              Navigator.of(context).pop(),
            },
        onError: (_) => {
              progressDialog.dismiss(),
              Fluttertoast.showToast(msg: "登录失败，请检查用户名和密码是否正确！")
            });
  }

  void _showLoginDialog({bool forceLogin = false}) {
    var nameController = new TextEditingController();
    var pwdController = new TextEditingController();
    showDialog<Null>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: Text("登录Fudan UIS"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: "UIS账号", icon: Icon(Icons.perm_identity)),
                  autofocus: true,
                ),
                TextField(
                  controller: pwdController,
                  decoration: InputDecoration(
                      labelText: "UIS密码", icon: Icon(Icons.lock_outline)),
                  obscureText: true,
                )
              ],
            ),
            actions: [
              FlatButton(
                child: Text("取消"),
                onPressed: () {
                  if (forceLogin)
                    Navigator.of(context).pop();
                  else
                    exit(0);
                },
              ),
              FlatButton(
                child: Text("登录"),
                onPressed: () async {
                  if (nameController.text.length * pwdController.text.length >
                      0) {
                    _tryLogin(nameController.text, pwdController.text);
                  }
                },
              )
            ],
          );
        });
  }

  Future<void> _loadSharedPreference({bool forceLogin = false}) async {
    _preferences = await SharedPreferences.getInstance();
    if (!_preferences.containsKey("id") || forceLogin) {
      _showLoginDialog(forceLogin: forceLogin);
    } else {
      setState(() {
        _personInfo.value = new PersonInfo(_preferences.getString("id"),
            _preferences.getString("password"), _preferences.getString("name"));
      });
    }
  }

  Future<void> _loadNetworkState() async {
    var connectivity = await WiFiUtils.getConnectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.wifi) {
      var result;
      try {
        result = await WiFiUtils.getWiFiInfo(connectivity);
      } catch (e) {
        print(e);
      }
      setState(() {
        _connectStatus.value = result == null || result['name'] == null
            ? "获取WiFi名称失败，检查位置服务开启情况"
            : FDUWiFiConverter.recognizeWiFi(result['name']);
      });
    } else {
      setState(() {
        _connectStatus.value = "没有链接到WiFi";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Start run");

    return _personInfo == null
        ? Scaffold(
            appBar: AppBar(
            title: Text(widget.title),
          ))
        : Scaffold(
      appBar: AppBar(
              title: Text(
                widget.title,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: _connectStatus),
                ChangeNotifierProvider.value(value: _personInfo),
              ],
              child: _subpageBuilders[0](),
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                  backgroundColor: Colors.purple,
                  icon: Icon(Icons.home),
                  label: "首页",
                ),
                BottomNavigationBarItem(
                  backgroundColor: Colors.indigo,
                  icon: Icon(Icons.forum),
                  label: "论坛",
                ),
                BottomNavigationBarItem(
                  backgroundColor: Colors.blue,
                  icon: Icon(Icons.person),
                  label: "我",
                ),
              ],
              currentIndex: _pageindex,
              type: BottomNavigationBarType.shifting,
              onTap: (index) {
                if (index != _pageindex) {
                  setState(() {
                    _pageindex = index;
                  });
                }
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                await _loadSharedPreference(forceLogin: true);
              },
              tooltip: '切换账号',
              child: Icon(Icons.login),
            ),
          );
  }
}
