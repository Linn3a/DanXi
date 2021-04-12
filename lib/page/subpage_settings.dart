/*
 *     Copyright (C) 2021 kavinzhao
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:ui';

import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/person.dart';
import 'package:dan_xi/page/open_source_license.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/public_extension_methods.dart';
import 'package:dan_xi/util/flutter_app.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/widget/login_dialog/login_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_sfsymbols/flutter_sfsymbols.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsSubpage extends PlatformSubpage {
  @override
  bool get needPadding => true;

  @override
  _SettingsSubpageState createState() => _SettingsSubpageState();

  SettingsSubpage({Key key});
}

class _SettingsSubpageState extends State<SettingsSubpage> {
  /// All open-source license for the app.
  static const List<LicenseItem> _LICENSE_ITEMS = [
    LicenseItem("dio", LICENSE_MIT, "https://github.com/flutterchina/dio"),
    LicenseItem("beautifulsoup", LICENSE_APACHE_2_0,
        "https://github.com/Sach97/beautifulsoup.dart"),
    LicenseItem("build_runner", LICENSE_BSD,
        "https://github.com/dart-lang/build/tree/master/build_runner"),
    LicenseItem(
        "catcher", LICENSE_APACHE_2_0, "https://github.com/jhomlala/catcher"),
    LicenseItem("connectivity_plus", LICENSE_BSD,
        "https://github.com/fluttercommunity/plus_plugins/tree/main/packages/"),
    LicenseItem("cupertino_icons", LICENSE_MIT,
        "https://github.com/flutter/cupertino_icons"),
    LicenseItem("data_plugin", LICENSE_NO, "https://github.com/chaozhouzhang"),
    LicenseItem("dio_cookie_manager", LICENSE_MIT,
        "https://github.com/flutterchina/dio"),
    LicenseItem("event_bus", LICENSE_MIT,
        "https://github.com/marcojakob/dart-event-bus"),
    LicenseItem("flutter", LICENSE_BSD_3_0_CLAUSE,
        "https://github.com/flutter/flutter"),
    LicenseItem("flutter_inappwebview", LICENSE_APACHE_2_0,
        "https://github.com/pichillilorenzo/flutter_inappwebview"),
    //TODO items below need recheck
    LicenseItem("flutter_localizations", LICENSE_BSD_3_0_CLAUSE,
        "https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html"),
    LicenseItem("flutter_platform_widgets", LICENSE_MIT,
        "https://github.com/stryder-dev/flutter_platform_widgets"),
    LicenseItem("flutter_progress_dialog", LICENSE_APACHE_2_0,
        "https://github.com/wuzhendev/flutter_progress_dialog"),
    LicenseItem("flutter_sfsymbols", LICENSE_APACHE_2_0,
        "https://github.com/virskor/flutter_sfsymbols"),
    LicenseItem("flutter_test", LICENSE_BSD_3_0_CLAUSE,
        "https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html"),
    LicenseItem("flutter_timetable_view", LICENSE_MIT,
        "https://github.com/yamarkz/flutter_timetable_view"),
    LicenseItem("http", LICENSE_BSD, "https://github.com/dart-lang/http"),
    LicenseItem("ical", LICENSE_BSD, "https://github.com/dartclub/ical"),
    LicenseItem("intl", LICENSE_BSD, "https://github.com/dart-lang/intl"),
    LicenseItem("json_serializable", LICENSE_BSD,
        "https://github.com/google/json_serializable.dart/tree/master/json_serializable"),
    LicenseItem("network_info_plus", LICENSE_BSD,
        "https://github.com/fluttercommunity/plus_plugins/tree/main/packages/"),
    LicenseItem(
        "path_provider", LICENSE_BSD, "https://github.com/flutter/plugins"),
    LicenseItem(
        "provider", LICENSE_MIT, "https://github.com/rrousselGit/provider"),
    LicenseItem(
        "qr_flutter", LICENSE_BSD, "https://github.com/theyakka/qr.flutter"),
    LicenseItem(
        "quick_actions", LICENSE_BSD, "https://github.com/flutter/plugins"),
    LicenseItem("screen", LICENSE_MIT,
        "https://github.com/clovisnicolas/flutter_screen"),
    LicenseItem("share", LICENSE_BSD, "https://github.com/flutter/plugins"),
    LicenseItem("shared_preferences", LICENSE_BSD,
        "https://github.com/flutter/plugins"),
    LicenseItem(
        "url_launcher", LICENSE_BSD, "https://github.com/flutter/plugins"),
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _deleteAllDataAndExit() async {
    SharedPreferences _preferences = await SharedPreferences.getInstance();
    await _preferences.clear().then((value) =>
    {
      showPlatformDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => PlatformAlertDialog(
          title: Text(S.of(context).logout_question_prompt_title),
          content: Text(S.of(context).logout_question_prompt),
          actions: [
            PlatformDialogAction(
              child: Text(S.of(context).cancel),
              onPressed: (){
                Navigator.of(context).pop();
          },),
            PlatformDialogAction(
              child: Text(S.of(context).i_see),
              onPressed: (){
                FlutterApp.exitApp();
                },),],
        ),
      ),
      showPlatformDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => PlatformAlertDialog(
            content: Text(S.of(context).logout_prompt),
        ),
      )
    }
    );
  }

  SharedPreferences _preferences;

  void initLogin({bool forceLogin = false}) {
    _showLoginDialog(forceLogin: forceLogin);
  }

  /// Pop up a dialog where user can give his name & password.
  void _showLoginDialog({bool forceLogin = false}) {
    ValueNotifier<PersonInfo> _infoNotifier =
        Provider.of<ValueNotifier<PersonInfo>>(context, listen: false);
    showPlatformDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => LoginDialog(
            sharedPreferences: _preferences,
            personInfo: _infoNotifier,
            forceLogin: forceLogin));
  }

  List<Widget> _buildCampusAreaList() {
    List<Widget> list = [];
    Function onTapListener = (Campus campus) {
      SettingsProvider.of(_preferences).campus = campus;
      Navigator.of(context).pop();
      refreshSelf();
    };
    Constant.CAMPUS_VALUES.forEach((value) {
      list.add(PlatformWidget(
        cupertino: (_, __) => CupertinoActionSheetAction(
          onPressed: () => onTapListener(value),
          child: Text(value.displayTitle(context)),
        ),
        material: (_, __) => ListTile(
          title: Text(value.displayTitle(context)),
          onTap: () => onTapListener(value),
        ),
      ));
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    _preferences = Provider.of<SharedPreferences>(context);

    const double _avatarSpacing = 56;
    double _avatarSize =
        (MediaQuery.of(context).size.width - _avatarSpacing * 3 - 40) / 3;
    const double _avatarNameSpacing = 4;
    //TODO: WARNING Hardcoded avatarSize Modifiers!

    return RefreshIndicator(
        onRefresh: () async => refreshSelf(),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ListView(padding: EdgeInsets.all(4), children: <Widget>[
            //Account Selection
            Card(
              child: Column(
              children: <Widget>[
                ListTile(
                  title: Text(S.of(context).account),
                  leading: PlatformX.isMaterial(context)
                      ? const Icon(Icons.account_circle)
                      : const Icon(SFSymbols.person_circle),
                  subtitle: Text(context.personInfo.name +
                      ' (' +
                      context.personInfo.id +
                      ')'),
                  onTap: () => initLogin(forceLogin: true),
                ),
                ListTile(
                  title: Text(S.of(context).logout),
                  leading: PlatformX.isMaterial(context)
                      ? const Icon(Icons.delete_forever)
                      : const Icon(SFSymbols.trash),
                  subtitle: Text(S.of(context).logout_subtitle),
                  onTap: () {
                    _deleteAllDataAndExit();
                  },
                ),
              ]),
            ),

            //Campus Selection
            Card(
              child: ListTile(
                title: Text(S.of(context).default_campus),
                leading: PlatformX.isMaterial(context)
                    ? const Icon(Icons.location_city)
                    : const Icon(SFSymbols.location),
                subtitle: Text(SettingsProvider.of(_preferences)
                    .campus
                    .displayTitle(context)),
                onTap: () {
                  if (_preferences != null) {
                    showPlatformModalSheet(
                        context: context,
                        builder: (_) => PlatformWidget(
                              cupertino: (_, __) => CupertinoActionSheet(
                                title: Text(S.of(context).select_campus),
                                actions: _buildCampusAreaList(),
                              ),
                              material: (_, __) => Container(
                                height: 300,
                                child: Column(children: _buildCampusAreaList()),
                              ),
                            ));
                  }
                },
              ),
            ),

            //About Page
            Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ListTile(
                    leading: PlatformX.isMaterial(context)
                    ? const Icon(Icons.info)
                        : const Icon(SFSymbols.info_circle),
                    title: Text(S.of(context).about),
                  ),
                  Container(
                    padding: new EdgeInsets.fromLTRB(25, 5, 25, 0),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            S.of(context).app_description_title,
                            textScaleFactor: 1.1,
                          ),
                          Divider(),
                          Text(S.of(context).app_description),
                          const SizedBox(
                            height: 16,
                          ),
                          Text(
                            S.of(context).authors,
                            textScaleFactor: 1.1,
                          ),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  InkWell(
                                    child: Container(
                                        width: _avatarSize,
                                        height: _avatarSize,
                                        decoration: new BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: new DecorationImage(
                                                fit: BoxFit.fill,
                                                image: new AssetImage(S
                                                    .of(context)
                                                    .dev_image_url_1)))),
                                    onTap: () =>
                                        launch(S.of(context).dev_page_1),
                                  ),
                                  const SizedBox(height: _avatarNameSpacing),
                                  Text(
                                    S.of(context).dev_name_1,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              const SizedBox(width: _avatarSpacing),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  InkWell(
                                    child: Container(
                                        width: _avatarSize,
                                        height: _avatarSize,
                                        decoration: new BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: new DecorationImage(
                                                fit: BoxFit.fill,
                                                image: new AssetImage(S
                                                    .of(context)
                                                    .dev_image_url_2)))),
                                    onTap: () =>
                                        launch(S.of(context).dev_page_2),
                                  ),
                                  const SizedBox(height: _avatarNameSpacing),
                                  Text(
                                    S.of(context).dev_name_2,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              const SizedBox(width: _avatarSpacing),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  InkWell(
                                    child: Container(
                                        width: _avatarSize,
                                        height: _avatarSize,
                                        decoration: new BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: new DecorationImage(
                                                fit: BoxFit.fill,
                                                image: new AssetImage(S
                                                    .of(context)
                                                    .dev_image_url_3)))),
                                    onTap: () {
                                      launch(S.of(context).dev_page_3);
                                    },
                                  ),
                                  const SizedBox(height: _avatarNameSpacing),
                                  Text(
                                    S.of(context).dev_name_3,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                S.of(context).author_descriptor,
                                textScaleFactor: 0.7,
                                textAlign: TextAlign.right,
                                //style: TextStyle(fontStyle: FontStyle.italic)),
                              )
                            ],
                          ),
                        ]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        child:
                            Text(S.of(context).open_source_software_licenses),
                        onPressed: () {
                          Navigator.of(context).pushNamed("/about/openLicense",
                              arguments: {"items": _LICENSE_ITEMS});
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        child: Text(S.of(context).project_page),
                        onPressed: () {
                          launch(S.of(context).project_url);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ));
  }
}
