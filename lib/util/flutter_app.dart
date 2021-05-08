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

import 'dart:io';

import 'package:dan_xi/util/platform_universal.dart';
import 'package:flutter/services.dart';

class FlutterApp {
  static void exitApp() {
    if (PlatformX.isAndroid) {
      SystemNavigator.pop(animated: true);
    }
    else if (PlatformX.isIOS) {
      const channel = const MethodChannel('appControl');
      channel.invokeMethod('exit'); //TODO: WARNING This might not pass App Store Review
    }
    else {
      exit(0);
    }
  }
}
