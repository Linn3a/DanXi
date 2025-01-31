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

import 'dart:async';
import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:collection/collection.dart';
import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/opentreehole/division.dart';
import 'package:dan_xi/model/opentreehole/floor.dart';
import 'package:dan_xi/model/opentreehole/hole.dart';
import 'package:dan_xi/model/opentreehole/tag.dart';
import 'package:dan_xi/page/opentreehole/hole_editor.dart';
import 'package:dan_xi/page/opentreehole/image_viewer.dart';
import 'package:dan_xi/page/subpage_treehole.dart';
import 'package:dan_xi/provider/fduhole_provider.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/provider/state_provider.dart';
import 'package:dan_xi/repository/opentreehole/opentreehole_repository.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/opentreehole/paged_listview_helper.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/widget/libraries/future_widget.dart';
import 'package:dan_xi/widget/libraries/paged_listview.dart';
import 'package:dan_xi/widget/libraries/platform_app_bar_ex.dart';
import 'package:dan_xi/widget/libraries/platform_context_menu.dart';
import 'package:dan_xi/widget/libraries/top_controller.dart';
import 'package:dan_xi/widget/opentreehole/ottag_selector.dart';
import 'package:dan_xi/widget/opentreehole/post_render.dart';
import 'package:dan_xi/widget/opentreehole/render/base_render.dart';
import 'package:dan_xi/widget/opentreehole/render/render_impl.dart';
import 'package:dan_xi/widget/opentreehole/treehole_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_progress_dialog/flutter_progress_dialog.dart';
import 'package:intl/intl.dart';
import 'package:linkify/linkify.dart';
import 'package:nil/nil.dart';
import 'package:provider/provider.dart';

import '../../model/opentreehole/history.dart';

/// This function preprocesses content downloaded from FDUHOLE so that
/// (1) HTML href is added to raw links
/// (2) Markdown Images are converted to HTML images.
String preprocessContentForDisplay(String content) {
  String result = "";

  linkify(content, options: const LinkifyOptions(humanize: false))
      .forEach((element) {
    if (element is UrlElement) {
      // Only add tag if tag has not yet been added.
      if (RegExp("\\[.*?\\]\\(${RegExp.escape(element.url)}\\)")
              .hasMatch(content) ||
          RegExp("\\[.*?${RegExp.escape(element.url)}.*?\\]\\(http.*?\\)")
              .hasMatch(content)) {
        result += element.url;
      } else {
        result += "[${element.text}](${element.url})";
      }
    } else {
      result += element.text;
    }
  });

  return result;
}

/// A list page showing the content of a bbs post.
///
/// Arguments:
/// [OTHole] or [Future<List<OTFloor>>] post: if [post] is [OTHole], show the page as a post.
/// Otherwise as a list of search result.
/// When [post] is [OTHole] and its [prefetch] is more than [Constant.POST_COUNT_PER_PAGE], it supposes *all* the floors has been prefetched.
///
/// [String] searchKeyword: if set, the page will show the result of searching [searchKeyword].
///
/// [bool] punishmentHistory: if set AND true (i.e. [punishmentHistory == true]), the page will show the punishment history of the post.
///
/// [bool] scroll_to_end: if [scroll_to_end] is true, the page will scroll to the end of
/// the post as soon as the page shows. This implies that [post] should be a [OTHole].
/// If [scroll_to_end] is true, *all* the floors should be prefetched beforehand.
///
/// * See [hasPrefetchedAllData] below.
class BBSPostDetail extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const BBSPostDetail({Key? key, this.arguments}) : super(key: key);

  @override
  BBSPostDetailState createState() => BBSPostDetailState();
}

class BBSPostDetailState extends State<BBSPostDetail> {
  /// Unrelated to the state.
  /// These field should only be initialized once when created.
  late OTHole _hole;
  RenderMode _renderMode = RenderMode.NORMAL;
  String? _searchKeyword;
  FileImage? _backgroundImage;

  /// Fields related to the display states.
  bool? _isFavored;
  bool _onlyShowDZ = false;
  bool _multiSelectMode = false;
  final List<int> _selectedFloors = [];

  bool shouldScrollToEnd = false;
  OTFloor? locateFloor;

  final PagedListViewController<OTFloor> _listViewController =
      PagedListViewController<OTFloor>();

  bool get hasPrefetchedAllData =>
      shouldScrollToEnd ||
      (_hole.floors?.prefetch?.length ?? -1) > Constant.POST_COUNT_PER_PAGE;

  /// Reload/load the (new) content and set the [_content] future.
  Future<List<OTFloor>?> _loadContent(int page) async {
    Future<List<OTFloor>?> loadPunishmentHistory(int page) async {
      if (page == 0) {
        return (await OpenTreeHoleRepository.getInstance()
                .getPunishmentHistory())
            ?.map((e) => e.floor!)
            .toList();
      } else {
        // notify the list view that there is no more data - the first page is the last page.
        return [];
      }
    }

    return switch (_renderMode) {
      RenderMode.NORMAL => await OpenTreeHoleRepository.getInstance()
          .loadFloors(_hole, startFloor: page * Constant.POST_COUNT_PER_PAGE),
      RenderMode.SEARCH_RESULT => await OpenTreeHoleRepository.getInstance()
          .loadSearchResults(_searchKeyword,
              startFloor: _listViewController.length()),
      RenderMode.PUNISHMENT_HISTORY => await loadPunishmentHistory(page),
    };
  }

  Future<bool?> _isHoleFavorite() async {
    if (_isFavored != null) return _isFavored;
    final List<int>? favorites =
        await (OpenTreeHoleRepository.getInstance().getFavoriteHoleId());
    return favorites!.any((elementId) => elementId == _hole.hole_id);
  }

  // construct the uri of the floor and copy it to clipboard
  Future<bool> _shareFloorAsUri(int? floorId) async {
    String uri = 'https://www.fduhole.com/floor/$floorId';
    try {
      if (floorId == null) return false;
      FlutterClipboard.copy(uri);
    } catch (e) {
      return false;
    }
    return true;
  }

  // construct the uri of the hole and copy it to clipboard
  Future<bool> _shareHoleAsUri(int? holeId) async {
    String uri = 'https://www.fduhole.com/hole/$holeId';
    try {
      if (holeId == null) return false;
      FlutterClipboard.copy(uri);
    } catch (e) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.arguments!.containsKey('post')) {
      _renderMode = RenderMode.NORMAL;
      _hole = widget.arguments!['post'];
      // Cache preloaded floor only when user views the Hole
      for (var floor
          in _hole.floors?.prefetch ?? List<OTFloor>.empty(growable: false)) {
        OpenTreeHoleRepository.getInstance().cacheFloor(floor);
      }
      // Update hole view count
      if (_hole.hole_id != null) {
        unawaited(OpenTreeHoleRepository.getInstance()
            .updateHoleViewCount(_hole.hole_id!));
      }
    } else if (widget.arguments!.containsKey('searchKeyword')) {
      _renderMode = RenderMode.SEARCH_RESULT;
      _searchKeyword = widget.arguments!['searchKeyword'];
      // Create a dummy post for displaying search result
      _hole = OTHole.dummy();
    } else if (widget.arguments!.containsKey('punishmentHistory') &&
        widget.arguments!['punishmentHistory'] == true) {
      _renderMode = RenderMode.PUNISHMENT_HISTORY;
      // Create a dummy post for displaying punishment history
      _hole = OTHole.dummy();
    }

    shouldScrollToEnd = widget.arguments!.containsKey('scroll_to_end') &&
        widget.arguments!['scroll_to_end'] == true;
    if (widget.arguments!.containsKey('locate')) {
      locateFloor = widget.arguments!["locate"];
    }

    StateProvider.needScreenshotWarning = true;
  }

  /// Refresh the list view.
  ///
  /// if [ignorePrefetch] and [hasPrefetchedAllData], it will discard the prefetched data first.
  Future<void> refreshListView(
      {bool scrollToEnd = false, bool ignorePrefetch = true}) async {
    Future<void> realRefresh() async {
      if (scrollToEnd) _listViewController.queueScrollToEnd();
      await _listViewController.notifyUpdate(
          useInitialData: false, queueDataClear: true);
    }

    if (ignorePrefetch && hasPrefetchedAllData) {
      // Reset variable to make [hasPrefetchedAllData] false
      setState(() {
        shouldScrollToEnd = false;
        _hole.floors?.prefetch =
            _hole.floors?.prefetch?.take(Constant.POST_COUNT_PER_PAGE).toList();
      });

      // Wait build() complete (so `allDataReceiver` has been set to `null`), then trigger a refresh in
      // the list view.
      Completer<void> completer = Completer();
      WidgetsBinding.instance.addPostFrameCallback((_) => realRefresh()
          .then(completer.complete, onError: completer.completeError));
      return completer.future;
    }
    return realRefresh();
  }

  @override
  void dispose() {
    StateProvider.needScreenshotWarning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Replaced precached data with updated ones
        _listViewController.replaceInitialData(
            (await OpenTreeHoleRepository.getInstance().loadFloors(_hole))!);
      } catch (_) {}
      if (locateFloor != null && mounted) {
        try {
          // Scroll to the specific floor
          await PagedListViewHelper.scrollToItem(
              context, _listViewController, locateFloor, ScrollDirection.DOWN);
          locateFloor = null;
        } catch (_) {}
      }
    });
    _backgroundImage = SettingsProvider.getInstance().backgroundImage;
    Future<List<OTFloor>>? allDataReceiver;
    if (hasPrefetchedAllData) {
      allDataReceiver = Future.value(_hole.floors?.prefetch);
    }
    final pagedListView = PagedListView<OTFloor>(
      initialData: _hole.floors?.prefetch,
      pagedController: _listViewController,
      noneItem: OTFloor.dummy(),
      withScrollbar: true,
      scrollController: PrimaryScrollController.of(context),
      dataReceiver: _loadContent,
      // If we need to scroll to the end, we should prefetch all the data beforehand.
      // See also [prefetchAllFloors] in [TreeHoleSubpageState].
      allDataReceiver: allDataReceiver,
      shouldScrollToEnd: shouldScrollToEnd,
      builder: _getListItems,
      loadingBuilder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        child: Center(child: PlatformCircularProgressIndicator()),
      ),
      endBuilder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text((_hole.view ?? -1) >= 0
              ? S.of(context).view_count(_hole.view.toString())
              : S.of(context).end_reached),
        ),
      ),
      // Only show empty message when searching, for now.
      emptyBuilder: _renderMode != RenderMode.NORMAL
          ? (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(S.of(context).no_data),
                ),
              )
          : null,
    );

    return PlatformScaffold(
      iosContentPadding: false,
      iosContentBottomPadding: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PlatformAppBarX(
        title: TopController(
          controller: PrimaryScrollController.of(context),
          child: switch (_renderMode) {
            RenderMode.NORMAL => Text("#${_hole.hole_id}"),
            RenderMode.SEARCH_RESULT => Text(S.of(context).search_result),
            RenderMode.PUNISHMENT_HISTORY =>
              Text(S.of(context).list_my_punishments),
          },
        ),
        trailingActions: [
          if (_renderMode == RenderMode.NORMAL) ...[
            _buildFavoredActionButton(),
            PlatformIconButton(
              padding: EdgeInsets.zero,
              icon: PlatformX.isMaterial(context)
                  ? const Icon(Icons.reply)
                  : const Icon(CupertinoIcons.arrowshape_turn_up_left),
              onPressed: () async {
                if (await OTEditor.createNewReply(
                    context, _hole.hole_id, null)) {
                  refreshListView(scrollToEnd: true);
                }
              },
            ),
            PlatformPopupMenuX(
              options: [
                PopupMenuOption(
                    label: S.of(context).scroll_to_end,
                    onTap: _onTapScrollToEnd),
                PopupMenuOption(
                    label: _onlyShowDZ
                        ? S.of(context).show_all_replies
                        : S.of(context).only_show_dz,
                    onTap: (_) {
                      setState(() => _onlyShowDZ = !_onlyShowDZ);
                      refreshListView(ignorePrefetch: false);
                    }),
                PopupMenuOption(
                    label: _multiSelectMode
                        ? S.of(context).multiple_select_mode_exit
                        : S.of(context).multiple_select_mode_enter,
                    onTap: (_) {
                      setState(() {
                        _multiSelectMode = !_multiSelectMode;
                        // if we have just entered multi-choice mode, clear the selected floors.
                        if (_multiSelectMode) {
                          _selectedFloors.clear();
                        }
                      });
                    }),
                PopupMenuOption(
                  label: S.of(context).share_hole,
                  onTap: (_) async {
                    if (await _shareHoleAsUri(_hole.hole_id)) {
                      if (mounted) {
                        Noticing.showMaterialNotice(
                            context, S.of(context).shareHoleSuccess);
                      }
                    }
                  },
                ),
                PopupMenuOption(
                  label: S.of(context).copy_hole_id,
                  onTap: (_) async {
                    FlutterClipboard.copy('#${_hole.hole_id}');
                    if (mounted) {
                      Noticing.showMaterialNotice(
                          context, S.of(context).copy_hole_id_success);
                    }
                  },
                ),
                PopupMenuOption(
                    label: S.of(context).hide_hole,
                    onTap: (_) async {
                      bool? result = await Noticing.showConfirmationDialog(
                          context, S.of(context).hide_hole_confirm,
                          isConfirmDestructive: true);
                      if (result == true) {
                        var list = SettingsProvider.getInstance().hiddenHoles;
                        if (_hole.hole_id != null &&
                            !list.contains(_hole.hole_id!)) {
                          list.add(_hole.hole_id!);
                          SettingsProvider.getInstance().hiddenHoles = list;
                        }
                        if (mounted) {
                          Noticing.showNotice(
                              context, S.of(context).hide_hole_success);
                        }
                      }
                    }),
              ],
              cupertino: (context, platform) => CupertinoPopupMenuData(
                  cancelButtonData: CupertinoPopupMenuCancelButtonData(
                      child: Text(S.of(context).cancel))),
              icon: PlatformX.isMaterial(context)
                  ? const Icon(Icons.more_vert)
                  : const Icon(CupertinoIcons.ellipsis),
            ),
          ]
        ],
      ),
      body: Builder(
        // The builder widget updates context so that MediaQuery below can use the correct context (that is, Scaffold considered)
        builder: (context) => Container(
          decoration: _backgroundImage == null
              ? null
              : BoxDecoration(
                  image: DecorationImage(
                      image: _backgroundImage!, fit: BoxFit.cover)),
          child: _renderMode == RenderMode.NORMAL
              ? RefreshIndicator(
                  edgeOffset: MediaQuery.of(context).padding.top,
                  color: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(context).dialogBackgroundColor,
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await refreshListView();
                  },
                  child: pagedListView,
                )
              : pagedListView,
        ),
      ),
    );
  }

  Future<void> _onTapScrollToEnd(_) async {
    ProgressFuture dialog = showProgressDialog(
        loadingText: S.of(context).loading, context: context);
    try {
      // If we haven't loaded before, we need to load all floors.
      if (!shouldScrollToEnd) _hole = await prefetchAllFloors(_hole);

      _listViewController.queueScrollToEnd();
      _listViewController.replaceDataWith((_hole.floors?.prefetch)!);
      setState(() {});
      shouldScrollToEnd = true;
    } catch (error, st) {
      Noticing.showErrorDialog(context, error, trace: st);
    } finally {
      dialog.dismiss(showAnim: false);
    }
  }

  Widget _buildFavoredActionButton() => PlatformIconButton(
        padding: EdgeInsets.zero,
        icon: FutureWidget<bool?>(
          future: _isHoleFavorite(),
          loadingBuilder: PlatformCircularProgressIndicator(),
          successBuilder:
              (BuildContext context, AsyncSnapshot<bool?> snapshot) {
            _isFavored = snapshot.data;
            return _isFavored!
                ? Icon(PlatformX.isMaterial(context)
                    ? Icons.star
                    : CupertinoIcons.star_fill)
                : Icon(PlatformX.isMaterial(context)
                    ? Icons.star_outline
                    : CupertinoIcons.star);
          },
          errorBuilder: () => Icon(
            PlatformIcons(context).error,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        onPressed: () async {
          if (_isFavored == null) return;
          setState(() => _isFavored = !_isFavored!);
          await OpenTreeHoleRepository.getInstance()
              .setFavorite(
                  _isFavored! ? SetFavoriteMode.ADD : SetFavoriteMode.DELETE,
                  _hole.hole_id)
              .onError((dynamic error, stackTrace) {
            Noticing.showNotice(context, error.toString(),
                title: S.of(context).operation_failed, useSnackBar: false);
            setState(() => _isFavored = !_isFavored!);
            return null;
          });
        },
      );

  List<OTTag> deepCopyTagList(List<OTTag> list) =>
      list.map((e) => OTTag.fromJson(jsonDecode(jsonEncode(e)))).toList();

  List<Widget> _buildContextMenu(BuildContext menuContext, OTFloor e) {
    List<Widget> buildAdminPenaltyMenu(BuildContext menuContext, OTFloor e) {
      Future<void> onExecutePenalty(int level) async {
        // Confirm the operation
        bool? confirmed = await Noticing.showConfirmationDialog(context,
            "You are going to add a penalty of level $level to floor ${e.floor_id} in its division. Are you sure?",
            isConfirmDestructive: true);
        if (confirmed != true) return;

        int? result = await OpenTreeHoleRepository.getInstance()
            .adminAddPenalty(e.floor_id, level);
        if (result != null && result < 300 && mounted) {
          Noticing.showMaterialNotice(
              context, S.of(context).operation_successful);
        }
      }

      Future<void> onExecutePenaltyDays() async {
        // Input the number of days
        String? dayStr = await Noticing.showInputDialog(
            context, "Please input the number of days");
        if (dayStr == null) return;
        int? days = int.tryParse(dayStr);
        if (days == null) return;

        // Confirm the operation
        bool? confirmed = await Noticing.showConfirmationDialog(context,
            "You are going to add a penalty of $days days to floor ${e.floor_id} in its division. Are you sure?",
            isConfirmDestructive: true);
        if (confirmed != true) return;

        int? result = await OpenTreeHoleRepository.getInstance()
            .adminAddPenaltyDays(e.floor_id, days);
        if (result != null && result < 300 && mounted) {
          Noticing.showMaterialNotice(
              context, S.of(context).operation_successful);
        }
      }

      return [
        PlatformContextMenuItem(
          onPressed: () => onExecutePenalty(1),
          menuContext: menuContext,
          child: Text(S.of(context).level(1)),
        ),
        PlatformContextMenuItem(
          onPressed: () => onExecutePenalty(2),
          menuContext: menuContext,
          child: Text(S.of(context).level(2)),
        ),
        PlatformContextMenuItem(
          onPressed: () => onExecutePenalty(3),
          menuContext: menuContext,
          isDestructive: true,
          child: Text(S.of(context).level(3)),
        ),
        PlatformContextMenuItem(
          onPressed: onExecutePenaltyDays,
          menuContext: menuContext,
          isDestructive: true,
          child: const Text("Custom penalty..."),
        ),
      ];
    }

    List<Widget> buildAdminMenu(BuildContext menuContext, OTFloor e) {
      return [
        PlatformContextMenuItem(
          onPressed: () async {
            if (await OTEditor.modifyReply(
                context, e.hole_id, e.floor_id, e.content)) {
              Noticing.showMaterialNotice(
                  context, S.of(context).operation_successful);
            }
          },
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).modify_floor),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            if (await Noticing.showConfirmationDialog(
                    context, S.of(context).are_you_sure,
                    isConfirmDestructive: true) ==
                true) {
              final reason = await Noticing.showInputDialog(
                  context, S.of(context).input_reason);
              int? result = await OpenTreeHoleRepository.getInstance()
                  .adminDeleteFloor(e.floor_id, reason);
              if (result != null && result < 300 && mounted) {
                Noticing.showMaterialNotice(
                    context, S.of(context).operation_successful);
              }
            }
          },
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).delete_floor),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            bool? lock = await Noticing.showConfirmationDialog(
                context, "Lock or unlock the hole?",
                confirmText: "Lock", cancelText: "Unlock");
            if (lock != null) {
              int? result = await OpenTreeHoleRepository.getInstance()
                  .adminLockHole(e.hole_id, lock);
              if (result != null && result < 300 && mounted) {
                Noticing.showMaterialNotice(
                    context, S.of(context).operation_successful);
              }
            }
          },
          isDestructive: true,
          menuContext: menuContext,
          child: const Text("Lock/Unlock hole"),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            bool? hide = await Noticing.showConfirmationDialog(
                context, "Hide or unhide the hole?",
                confirmText: "Hide", cancelText: "Unhide");
            if (hide != null) {
              int? result = hide
                  ? await OpenTreeHoleRepository.getInstance()
                      .adminDeleteHole(e.hole_id)
                  : await OpenTreeHoleRepository.getInstance()
                      .adminUndeleteHole(e.hole_id);
              if (result != null && result < 300 && mounted) {
                Noticing.showMaterialNotice(
                    context, S.of(context).operation_successful);
              }
            }
          },
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).hide_hole),
        ),
        PlatformContextMenuItem(
          onPressed: () => showPlatformModalSheet(
              context: context,
              builder: (subMenuContext) => PlatformContextMenu(
                  actions: buildAdminPenaltyMenu(subMenuContext, e),
                  cancelButton: CupertinoActionSheetAction(
                    child: Text(S.of(subMenuContext).cancel),
                    onPressed: () => Navigator.of(subMenuContext).pop(),
                  ))),
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).add_penalty),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            bool? confirmed = await Noticing.showConfirmationDialog(
                context, S.of(context).are_you_sure_pin_unpin,
                isConfirmDestructive: true);
            if (confirmed != true || !mounted) return;

            FDUHoleProvider provider = context.read<FDUHoleProvider>();
            List<int> pinned = provider.currentDivision!.pinned!
                .map((hole) => hole.hole_id!)
                .toList();
            if (pinned.contains(e.hole_id!)) {
              pinned.remove(e.hole_id!);
            } else {
              pinned.add(e.hole_id!);
            }
            int? result = await OpenTreeHoleRepository.getInstance()
                .adminModifyDivision(
                    provider.currentDivision!.division_id!, null, null, pinned);
            if (result != null && result < 300 && mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(context).operation_successful);
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).pin_unpin_hole),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            final tag = await Noticing.showInputDialog(
                context, S.of(context).input_reason);
            if (tag == null) {
              return; // Note: don't return if tag is empty string, because user may want to clear the special tag with this
            }
            int? result = await OpenTreeHoleRepository.getInstance()
                .adminAddSpecialTag(tag, e.floor_id);
            if (result != null && result < 300 && mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(context).operation_successful);
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).add_special_tag),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            OTDivision selectedDivision = OpenTreeHoleRepository.getInstance()
                .getDivisions()
                .firstWhere(
                    (element) => element.division_id == _hole.division_id,
                    orElse: () => OTDivision(_hole.division_id, '', '', null));

            List<Widget> buildDivisionOptionsList(BuildContext cxt) {
              List<Widget> list = [];
              onTapListener(OTDivision newDivision) {
                Navigator.of(cxt).pop(newDivision);
              }

              OpenTreeHoleRepository.getInstance()
                  .getDivisions()
                  .forEach((value) {
                list.add(ListTile(
                  title: Text(value.name ?? "null"),
                  subtitle: Text(value.description ?? ""),
                  onTap: () => onTapListener(value),
                ));
              });
              return list;
            }

            final Widget divisionOptionsView = StatefulBuilder(
                builder: (BuildContext context, Function setState) => Listener(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selectedDivision.name ?? "?"),
                        const Icon(Icons.arrow_drop_down)
                      ],
                    ),
                    onPointerUp: (PointerUpEvent details) async {
                      if (context.read<FDUHoleProvider>().isUserInitialized &&
                          OpenTreeHoleRepository.getInstance()
                              .getDivisions()
                              .isNotEmpty) {
                        selectedDivision =
                            (await showPlatformModalSheet<OTDivision>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      final Widget content = Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: ListView(
                                              shrinkWrap: true,
                                              primary: false,
                                              children:
                                                  buildDivisionOptionsList(
                                                      context)));
                                      return PlatformX.isCupertino(context)
                                          ? SafeArea(
                                              child: Card(child: content))
                                          : SafeArea(child: content);
                                    })) ??
                                selectedDivision;
                        setState(() {});
                      }
                    }));

            final newTagsList = deepCopyTagList(_hole.tags ?? []);
            bool? confirmChanged = await showPlatformDialog<bool>(
              context: context,
              builder: (BuildContext context) => PlatformAlertDialog(
                title: Text(S.of(context).modify_tag_division),
                content: Column(
                  children: [
                    divisionOptionsView,
                    OTTagSelector(initialTags: newTagsList),
                  ],
                ),
                actions: <Widget>[
                  PlatformDialogAction(
                      child: PlatformText(S.of(context).cancel),
                      onPressed: () => Navigator.pop(context, false)),
                  PlatformDialogAction(
                      cupertino: (context, platform) =>
                          CupertinoDialogActionData(isDefaultAction: true),
                      child: PlatformText(S.of(context).i_see),
                      onPressed: () => Navigator.pop(context, true)),
                ],
              ),
            );
            if (confirmChanged ?? false) {
              int? result = await OpenTreeHoleRepository.getInstance()
                  .adminUpdateTagAndDivision(
                      newTagsList, _hole.hole_id, selectedDivision.division_id);
              if (result != null && result < 300 && mounted) {
                Noticing.showMaterialNotice(
                    context, S.of(context).operation_successful);
              }
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).modify_tag_division),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            final reason = await Noticing.showInputDialog(
                context, S.of(context).input_reason);
            if (reason == null) {
              return; // Note: don't return if tag is empty string, because user may want to clear the special tag with this
            }
            int? result = await OpenTreeHoleRepository.getInstance()
                .adminFoldFloor(reason.isEmpty ? [] : [reason], e.floor_id);
            if (result != null && result < 300 && mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(context).operation_successful);
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).fold_floor),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            List<String>? history = await OpenTreeHoleRepository.getInstance()
                .adminGetPunishmentHistory(e.floor_id!);
            if (history != null && mounted) {
              StringBuffer content = StringBuffer();
              for (int i = 0; i < history.length; i++) {
                content.writeln(history[i]);
                if (i < history.length - 1) {
                  content.writeln("================");
                }
              }
              Noticing.showModalNotice(context,
                  title: S.of(context).punishment_history_of(e.floor_id ?? "?"),
                  message: content.toString(),
                  selectable: true);
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).show_punishment_history),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            List<OTHistory>? history =
                await OpenTreeHoleRepository.getInstance()
                    .getHistory(e.floor_id);
            if (history != null && mounted) {
              StringBuffer content = StringBuffer();
              for (int i = 0; i < history.length; i++) {
                var record = history[i];
                content.writeln(
                    S.of(context).history_time(record.time_updated ?? "?"));
                content.writeln(
                    S.of(context).history_altered_by(record.user_id ?? "?"));
                content.writeln(S.of(context).original_content);
                content.writeln(record.content);
                if (i < history.length - 1) {
                  content.writeln("================");
                }
              }
              Noticing.showModalNotice(context,
                  title: S.of(context).history_of(e.floor_id ?? "?"),
                  message: content.toString(),
                  selectable: true);
            }
          },
          menuContext: menuContext,
          child: Text(S.of(context).view_history),
        ),
      ];
    }

    String postTime = DateFormat("yyyy/MM/dd HH:mm:ss")
        .format(DateTime.tryParse(e.time_created!)!.toLocal());
    String postTimeStr = S.of(menuContext).post_time(postTime);

    List<Widget> menu = [
      if (e.is_me == true && e.deleted == false)
        PlatformContextMenuItem(
          menuContext: menuContext,
          onPressed: () async {
            if (await OTEditor.modifyReply(
                context, e.hole_id, e.floor_id, e.content)) {
              Noticing.showMaterialNotice(
                  context, S.of(context).request_success);
            }
            // await refreshListView();
            // // Set duration to 0 to execute [jumpTo] to the top.
            // await _listViewController.scrollToIndex(0, const Duration());
            // await scrollDownToFloor(e);
          },
          child: Text(S.of(context).modify),
        ),

      // Standard Operations
      PlatformContextMenuItem(
          menuContext: menuContext,
          child: Text(postTimeStr),
          onPressed: () async {
            await FlutterClipboard.copy(postTimeStr);
            if (mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(menuContext).copy_success);
            }
          }),
      PlatformContextMenuItem(
        menuContext: menuContext,
        onPressed: () => smartNavigatorPush(context, "/text/detail",
            arguments: {"text": e.filteredContent}),
        child: Text(S.of(menuContext).free_select),
      ),
      PlatformContextMenuItem(
          menuContext: menuContext,
          child: Text(S.of(menuContext).copy),
          onPressed: () async {
            await FlutterClipboard.copy(renderText(e.filteredContent!, '', ''));
            if (mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(menuContext).copy_success);
            }
          }),
      PlatformContextMenuItem(
        menuContext: menuContext,
        onPressed: () async {
          FlutterClipboard.copy('##${e.floor_id}');
          if (mounted) {
            Noticing.showMaterialNotice(
                context, S.of(context).copy_floor_id_success);
          }
        },
        child: Text(S.of(context).copy_floor_id),
      ),
      PlatformContextMenuItem(
        menuContext: menuContext,
        onPressed: () async {
          if (await _shareFloorAsUri(e.floor_id)) {
            if (mounted) {
              Noticing.showMaterialNotice(
                  context, S.of(context).shareFloorSuccess);
            }
          }
        },
        child: Text(S.of(context).share_floor),
      ),
      PlatformContextMenuItem(
        menuContext: menuContext,
        isDestructive: true,
        onPressed: () async {
          if (await OTEditor.reportPost(context, e.floor_id)) {
            Noticing.showMaterialNotice(context, S.of(context).report_success);
          }
        },
        child: Text(S.of(menuContext).report),
      ),
      if (OpenTreeHoleRepository.getInstance().isAdmin) ...[
        PlatformContextMenuItem(
          onPressed: () => showPlatformModalSheet(
              context: context,
              builder: (subMenuContext) => PlatformContextMenu(
                  actions: buildAdminMenu(subMenuContext, e),
                  cancelButton: CupertinoActionSheetAction(
                    child: Text(S.of(subMenuContext).cancel),
                    onPressed: () => Navigator.of(subMenuContext).pop(),
                  ))),
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).admin_options),
        ),
      ]
    ];

    return menu;
  }

  List<Widget> _buildMultiSelectContextMenu(BuildContext menuContext) {
    Future<void> multiExecution(
        List<int> floorsList, Future<int?> Function(int floors) action) async {
      final floors = floorsList.toList();
      List<int?> results = await Future.wait(floors.map(action));

      List<int> successIds = [];
      List<int> failedIds = [];
      results.forEachIndexed((index, result) {
        if (result != null && result < 300) {
          successIds.add(floors[index]);
        } else {
          failedIds.add(floors[index]);
        }
      });
      if (mounted) {
        Noticing.showMaterialNotice(context,
            "${S.of(context).operation_successful}\nOK ($successIds), Failed ($failedIds)");
      }
    }

    List<Widget> buildAdminMenu(BuildContext menuContext) {
      return [
        PlatformContextMenuItem(
          onPressed: () async {
            if (await Noticing.showConfirmationDialog(
                    context, S.of(context).are_you_sure,
                    isConfirmDestructive: true) ==
                true) {
              final reason = await Noticing.showInputDialog(
                  context, S.of(context).input_reason);
              await multiExecution(
                  _selectedFloors,
                  (floor) async => await OpenTreeHoleRepository.getInstance()
                      .adminDeleteFloor(floor, reason));
            }
          },
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).delete_floor),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            final tag = await Noticing.showInputDialog(
                context, S.of(context).input_reason);
            if (tag == null) {
              return; // Note: don't return if tag is empty string, because user may want to clear the special tag with this
            }
            await multiExecution(
                _selectedFloors,
                (floor) async => await OpenTreeHoleRepository.getInstance()
                    .adminAddSpecialTag(tag, floor));
          },
          menuContext: menuContext,
          child: Text(S.of(context).add_special_tag),
        ),
        PlatformContextMenuItem(
          onPressed: () async {
            final reason = await Noticing.showInputDialog(
                context, S.of(context).input_reason);
            if (reason == null) {
              return; // Note: don't return if tag is empty string, because user may want to clear the special tag with this
            }
            await multiExecution(
                _selectedFloors,
                (floor) async => await OpenTreeHoleRepository.getInstance()
                    .adminFoldFloor(reason.isEmpty ? [] : [reason], floor));
          },
          menuContext: menuContext,
          child: Text(S.of(context).fold_floor),
        ),
      ];
    }

    List<Widget> menu = [
      if (OpenTreeHoleRepository.getInstance().isAdmin) ...[
        PlatformContextMenuItem(
          onPressed: () => showPlatformModalSheet(
              context: context,
              builder: (subMenuContext) => PlatformContextMenu(
                  actions: buildAdminMenu(subMenuContext),
                  cancelButton: CupertinoActionSheetAction(
                    child: Text(S.of(subMenuContext).cancel),
                    onPressed: () => Navigator.of(subMenuContext).pop(),
                  ))),
          isDestructive: true,
          menuContext: menuContext,
          child: Text(S.of(context).admin_options),
        ),
      ]
    ];

    return menu;
  }

  Widget _getListItems(BuildContext context, ListProvider<OTFloor> dataProvider,
      int index, OTFloor floor,
      {bool isNested = false}) {
    if (_onlyShowDZ &&
        _hole.floors?.first_floor?.anonyname != floor.anonyname) {
      return nil;
    }

    Future<List<ImageUrlInfo>?> loadPageImage(
        BuildContext pageContext, int pageIndex) async {
      List<OTFloor>? result = switch (_renderMode) {
        RenderMode.NORMAL => await OpenTreeHoleRepository.getInstance()
            .loadFloors(_hole,
                startFloor: pageIndex * Constant.POST_COUNT_PER_PAGE),
        RenderMode.SEARCH_RESULT => await OpenTreeHoleRepository.getInstance()
            .loadSearchResults(_searchKeyword,
                startFloor: pageIndex * Constant.POST_COUNT_PER_PAGE),
        RenderMode.PUNISHMENT_HISTORY =>
          (await OpenTreeHoleRepository.getInstance().getPunishmentHistory())
              ?.map((e) => e.floor!)
              .toList(),
      };

      if (result == null || result.isEmpty) {
        return null;
      } else {
        List<ImageUrlInfo> imageList = [];
        for (var floor in result) {
          if (floor.content == null) continue;
          imageList.addAll(extractAllImagesInFloor(floor.content!));
        }
        return imageList;
      }
    }

    final floorWidget = OTFloorWidget(
      hasBackgroundImage: _backgroundImage != null,
      floor: floor,
      index: _renderMode == RenderMode.NORMAL ? index : null,
      isInMention: isNested,
      parentHole: _hole,
      onLongPress: () async {
        showPlatformModalSheet(
            context: context,
            builder: (BuildContext context) => PlatformContextMenu(
                actions: _multiSelectMode
                    ? _buildMultiSelectContextMenu(context)
                    : _buildContextMenu(context, floor),
                cancelButton: CupertinoActionSheetAction(
                  child: Text(S.of(context).cancel),
                  onPressed: () => Navigator.of(context).pop(),
                )));
      },
      onTap: _multiSelectMode
          ? () {
              // If we are in multi-select mode, we should (un)select the floor.
              setState(() {
                if (_selectedFloors.contains(floor.floor_id)) {
                  _selectedFloors.remove(floor.floor_id);
                } else if (floor.floor_id != null) {
                  _selectedFloors.add(floor.floor_id!);
                }
              });
            }
          : () async {
              if (_renderMode == RenderMode.NORMAL) {
                int? replyId;
                // Set the replyId to null when tapping on the first reply.
                if (_hole.floors!.first_floor!.floor_id != floor.floor_id) {
                  replyId = floor.floor_id;
                  OpenTreeHoleRepository.getInstance().cacheFloor(floor);
                }
                if (await OTEditor.createNewReply(
                    context, _hole.hole_id, replyId)) {
                  await refreshListView(scrollToEnd: true);
                }
              } else {
                // fixme: duplicate of [OTFloorMentionWidget.showFloorDetail].
                ProgressFuture progressDialog = showProgressDialog(
                    loadingText: S.of(context).loading, context: context);
                try {
                  OTHole? hole = await OpenTreeHoleRepository.getInstance()
                      .loadSpecificHole(floor.hole_id!);
                  if (mounted) {
                    smartNavigatorPush(context, "/bbs/postDetail", arguments: {
                      "post": await prefetchAllFloors(hole!),
                      "locate": floor
                    });
                  }
                } catch (e, st) {
                  Noticing.showErrorDialog(context, e, trace: st);
                } finally {
                  progressDialog.dismiss(showAnim: false);
                }
              }
            },
      onTapImage: (String? url, Object heroTag) {
        final int length = _listViewController.length();
        smartNavigatorPush(context, '/image/detail', arguments: {
          'preview_url': url,
          'hd_url': OpenTreeHoleRepository.getInstance()
              .extractHighDefinitionImageUrl(url!),
          'hero_tag': heroTag,
          'image_list': extractAllImages(),
          'loader': loadPageImage,
          'last_page': length % Constant.POST_COUNT_PER_PAGE == 0
              ? (length ~/ Constant.POST_COUNT_PER_PAGE - 1)
              : length ~/ Constant.POST_COUNT_PER_PAGE
        });
      },
      searchKeyWord: _renderMode == RenderMode.SEARCH_RESULT
          ? _searchKeyword
          : null,
    );

    if (_multiSelectMode && _selectedFloors.contains(floor.floor_id)) {
      return Stack(
        children: [
          floorWidget,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  PlatformX.isMaterial(context)
                      ? Icons.check_circle
                      : CupertinoIcons.check_mark_circled_solid,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          )
        ],
      );
    } else {
      return floorWidget;
    }
  }

  Iterable<ImageUrlInfo> extractAllImagesInFloor(String content) {
    final imageExp = RegExp(r'!\[.*?\]\((.*?)\)');
    return imageExp.allMatches(content).map((e) => ImageUrlInfo(
        e.group(1),
        OpenTreeHoleRepository.getInstance()
            .extractHighDefinitionImageUrl(e.group(1)!)));
  }

  List<ImageUrlInfo> extractAllImages() {
    List<ImageUrlInfo> imageList = [];
    final int length = _listViewController.length();
    for (int i = 0; i < length; i++) {
      var floor = _listViewController.getElementAt(i);
      if (floor.content == null) continue;
      imageList.addAll(extractAllImagesInFloor(floor.content!));
    }
    return imageList;
  }
}

StatelessWidget smartRender(
    BuildContext context,
    String content,
    LinkTapCallback? onTapLink,
    ImageTapCallback? onTapImage,
    bool translucentCard,
    {bool preview = false}) {
  return PostRenderWidget(
    render: SettingsProvider.getInstance().isMarkdownRenderingEnabled
        ? kMarkdownRender
        : kPlainRender,
    content: preprocessContentForDisplay(content),
    onTapImage: onTapImage,
    onTapLink: onTapLink,
    hasBackgroundImage: translucentCard,
    isPreviewWidget: preview,
  );
}

enum RenderMode { NORMAL, SEARCH_RESULT, PUNISHMENT_HISTORY }
