/*
 *     Copyright (C) 2021  DanXi-Dev
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

import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/util/public_extension_methods.dart';
import 'package:dan_xi/util/stream_listener.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

class DankeSubPage extends PlatformSubpage<DankeSubPage> {
  @override
  DankeSubPageState createState() => DankeSubPageState();

  const DankeSubPage({Key? key}) : super(key: key);

  @override
  Create<Widget> get title => (cxt) => Text(S.of(cxt).danke);

  @override
  Create<List<AppBarButtonItem>> get trailing {
    return (cxt) => [
          AppBarButtonItem(S.of(cxt).refresh, Icon(PlatformIcons(cxt).refresh),
              () {
            RefreshPageEvent().fire();
          }),
          AppBarButtonItem(
              S.of(cxt).reset,
              Icon(PlatformX.isMaterial(cxt)
                  ? Icons.medical_services_outlined
                  : CupertinoIcons.rays), () {
            ResetWebViewEvent().fire();
          }),
        ];
  }
}

class RefreshPageEvent {}

class ResetWebViewEvent {}

class DankeSubPageState extends PlatformSubpageState<DankeSubPage> {
  InAppWebViewController? webViewController;
  static final StateStreamListener<RefreshPageEvent> _refreshSubscription =
      StateStreamListener();
  static final StateStreamListener<ResetWebViewEvent> _resetSubscription =
      StateStreamListener();

  URLRequest get urlRequest => URLRequest(
          url: Uri.https('danke.fduhole.com', '/jump', {
        'access': SettingsProvider.getInstance().fduholeToken?.access,
        'refresh': SettingsProvider.getInstance().fduholeToken?.refresh,
      }));

  @override
  void initState() {
    super.initState();
    _refreshSubscription.bindOnlyInvalid(
        Constant.eventBus
            .on<RefreshPageEvent>()
            .listen((event) => webViewController?.reload()),
        hashCode);
    _resetSubscription.bindOnlyInvalid(
        Constant.eventBus.on<ResetWebViewEvent>().listen((event) async {
          if (!mounted) return;
          bool? confirmed = await Noticing.showConfirmationDialog(
              context, S.of(context).fix_danke_description,
              title: S.of(context).fix);
          if (confirmed == true) {
            await webViewController?.clearCache();

            if (PlatformX.isAndroid) {
              await WebStorageManager.instance().android.deleteAllData();
            }
            if (PlatformX.isIOS) {
              final manager = WebStorageManager.instance().ios;
              var records = await manager.fetchDataRecords(
                  dataTypes: IOSWKWebsiteDataType.values);
              await manager.removeDataFor(
                  dataTypes: IOSWKWebsiteDataType.values,
                  dataRecords: records.filter((element) =>
                      element.displayName?.contains("fduhole.com") ?? false));
            }

            await HttpAuthCredentialDatabase.instance()
                .clearAllAuthCredentials();

            await CookieManager.instance().deleteAllCookies();

            await webViewController?.loadUrl(urlRequest: urlRequest);
          }
        }),
        hashCode);
  }

  @override
  void dispose() {
    super.dispose();
    _refreshSubscription.cancel();
    _resetSubscription.cancel();
  }

  @override
  Widget buildPage(BuildContext context) {
    InAppWebViewOptions settings =
        InAppWebViewOptions(userAgent: Constant.version);

    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (webViewController != null &&
              await webViewController!.canGoBack()) {
            await webViewController!.goBack();
            return false;
          }
          return true;
        },
        child: InAppWebView(
          initialOptions: InAppWebViewGroupOptions(crossPlatform: settings),
          initialUrlRequest: urlRequest,
          onWebViewCreated: (InAppWebViewController controller) {
            webViewController = controller;
          },
        ),
      ),
    );
  }
}
