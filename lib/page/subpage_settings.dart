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

import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/person.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/public_extension_methods.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/widget/login_dialog/login_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  @override
  void initState() {
    super.initState();
  }

  SharedPreferences _preferences;
  ValueNotifier<PersonInfo> _personInfo = ValueNotifier(null);
  Future<void> initSharedPreference({bool forceLogin = false}) async {
    _preferences = await SharedPreferences.getInstance();
    _showLoginDialog(forceLogin: forceLogin);
  }

  /// Pop up a dialog where user can give his name & password.
  void _showLoginDialog({bool forceLogin = false}) => showPlatformDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoginDialog(
          sharedPreferences: _preferences,
          personInfo: _personInfo,
          forceLogin: forceLogin));

  @override
  Widget build(BuildContext context) {

    double _avatarSize =  (MediaQuery.of(context).size.width-180) / 3;
    const double _avatarSpacing = 56;
    const double _avatarNameSpacing = 5;
    //TODO: WARNING Hardcoded avatarSize Modifiers!

    return RefreshIndicator(
        onRefresh: () async => refreshSelf(),
        child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              padding: EdgeInsets.all(4),
              children: <Widget>[

                //Account Selection
                Card(
                  child: ListTile(
                    title: Text(S.of(context).account),
                    leading: PlatformX.isAndroid
                        ? const Icon(Icons.account_circle)
                        : const Icon(SFSymbols.person_circle),
                    subtitle: Text(context.personInfo.name + ' (' + context.personInfo.id + ')'),
                    onTap: () async {
                      await initSharedPreference(forceLogin: true);
                      //TODO: Reload after account switch
                    },
                  ),
                ),

                //Campus Selection
                Card(
                  child: ListTile(
                    title: Text(S.of(context).default_campus),
                    leading: PlatformX.isAndroid
                        ? const Icon(Icons.location_city)
                        : const Icon(SFSymbols.location),
                    subtitle: Text(S.of(context).handan_campus), //TODO: is a stub
                    onTap: () {
                      //TODO
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
                        leading: PlatformX.isAndroid
                            ? const Icon(Icons.info)
                            : const Icon(SFSymbols.info_circle),
                        title: Text(S.of(context).about),
                        //subtitle: Text("TODO: is a stub"),
                      ),
                      Container(
                        padding: new EdgeInsets.fromLTRB(25,5,25,0),
                        child: new Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget> [
                              Text(S.of(context).app_description_title,textScaleFactor: 1.1,),
                              Divider(),
                              Text(S.of(context).app_description),
                              const SizedBox(height: 10,),
                              Text(S.of(context).authors,textScaleFactor: 1.1,),
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
                                                    image: new NetworkImage(
                                                        S.of(context).dev_image_url_1)
                                                )
                                            )),
                                        onTap: () {
                                          launch(S.of(context).dev_page_1);
                                        },
                                      ),
                                      const SizedBox(height: _avatarNameSpacing),
                                      Text(S.of(context).dev_name_1),
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
                                                    image: new NetworkImage(
                                                        S.of(context).dev_image_url_2)
                                                )
                                            )),
                                        onTap: () {
                                          launch(S.of(context).dev_page_2);
                                        },
                                      ),
                                      const SizedBox(height: _avatarNameSpacing),
                                      Text(S.of(context).dev_name_2),
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
                                                    image: new NetworkImage(
                                                        S.of(context).dev_image_url_3)
                                                )
                                            )),
                                        onTap: () {
                                          launch(S.of(context).dev_page_3);
                                        },
                                      ),
                                      const SizedBox(height: _avatarNameSpacing),
                                      Text(S.of(context).dev_name_3),
                                    ],
                                  ),
                                ],
                              ),
                            ]
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            child: Text(S.of(context).open_source_software_licenses),
                            onPressed: () {
                              showPlatformDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (BuildContext context) => PlatformAlertDialog(
                                    title: Text(S.of(context).open_source_software_licenses),
                                    content: Text(S.of(context).LICENSES),
                                    actions: <Widget>[
                                      PlatformDialogAction(
                                          child: PlatformText(S.of(context).i_see),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          }),
                                    ],
                                  ),

                              );
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
              ],
            )));
  }
}
