import 'dart:convert';

import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/http/dio_util.dart';
import 'package:FEhViewer/models/entity/gallery.dart';
import 'package:FEhViewer/utils/storage.dart';
import 'package:FEhViewer/values/storages.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';

import '../../utils/utility.dart';
import '../tag_database.dart';

class GalleryListParser {
  /// 获取热门画廊列表
  static Future<List<GalleryItemBean>> getPopular() async {
    Global.logger.w("获取热门");
    HttpManager httpManager = HttpManager.getInstance("https://e-hentai.org");
    const url = "/popular";

    var cookie = Global.profile?.token ?? "";

    Options options = Options(headers: {
      "Cookie": cookie,
    });

    var response = await httpManager.get(url, options: options);

    List<GalleryItemBean> list = await parseGalleryList(response);

    return list;
  }

  /// 获取默认画廊列表
  static Future<List<GalleryItemBean>> getGallery(
      {int page, String fromGid}) async {
    HttpManager httpManager = HttpManager.getInstance("https://e-hentai.org");

    var url = "";
    if (page != null && fromGid != null) {
      url = "/?page=$page&from=$fromGid";
    } else if (page != null) {
      url = "/?page=$page";
    }

    debugPrint('$url');

    var cookie = Global.profile?.token ?? "";

    Options options =
        Options(headers: {"Cookie": cookie, "Referer": "https://e-hentai.org"});

    var response = await httpManager.get(url, options: options);

    List<GalleryItemBean> list = await parseGalleryList(response);

    return list;
  }

  /// 获取收藏
  static Future<List<GalleryItemBean>> getFavorite({String favcat}) async {
    HttpManager httpManager = HttpManager.getInstance("https://e-hentai.org");

    //收藏时间排序
    var _order = Global?.profile?.ehConfig?.favoritesOrder;

    var url = "/favorites.php";
    if (favcat != null && favcat != "a") {
      url = "$url?favcat=$favcat";
    }

    if (_order != null) {
      url = "$url?inline_set=$_order";
    }
    debugPrint('$url');

    var cookie = Global.profile?.token ?? "";

    Options options = Options(headers: {
      "Cookie": cookie,
    });

    var response = await httpManager.get(url, options: options);

//    debugPrint(response.toString());

    List<GalleryItemBean> list =
        await parseGalleryList(response, isFavorite: true);

    return list;
  }

  /// 获取api
  static Future getGalleryApi(String req) async {
    HttpManager httpManager = HttpManager.getInstance("https://e-hentai.org");
    const url = "/api.php";

    var response = await httpManager.postForm(url, data: req);

    return response;
  }

  static void getMoreGalleryInfo(List<GalleryItemBean> galleryItems) async {
    debugPrint('api qry items ${galleryItems.length}');
    if (galleryItems.length == 0) {
      return;
    }

    // 通过api获取画廊详细信息
    List _gidlist = [];

    galleryItems.forEach((galleryItem) {
      _gidlist.add([galleryItem.gid, galleryItem.token]);
    });

    // 25个一组分割
    List _group = EHUtils.splitList(_gidlist, 25);

    List rultList = [];

    // 查询 合并结果
    for (int i = 0; i < _group.length; i++) {
      Map reqMap = {'gidlist': _group[i], 'method': 'gdata'};
      String reqJsonStr = jsonEncode(reqMap);
      var rult = await getGalleryApi(reqJsonStr);

      var jsonObj = jsonDecode(rult.toString());
      var tempList = jsonObj['gmetadata'];
      rultList.addAll(tempList);
    }
//    debugPrint('${rultList}');

    var unescape = new HtmlUnescape();

    for (int i = 0; i < galleryItems.length; i++) {
//      print('${galleryItems[i].simpleTags}    ${rultList[i]['tags']}');

      galleryItems[i].englishTitle = unescape.convert(rultList[i]['title']);
      galleryItems[i].japaneseTitle =
          unescape.convert(rultList[i]['title_jpn']);
      galleryItems[i].rating = double.parse(rultList[i]['rating']);
//      galleryItems[i].imgUrl = rultList[i]['thumb'];
      galleryItems[i].filecount = rultList[i]['filecount'];
    }
  }

  /// 列表数据处理
  static Future<List<GalleryItemBean>> parseGalleryList(String response,
      {isFavorite = false}) async {
    var document = parse(response);

    const GALLERY_SELECT =
        "body > div.ido > div:nth-child(2) > table > tbody > tr";
    const FAVORITE_SELECT =
        "body > div.ido > form > table.itg.gltc > tbody > tr";

    final select = isFavorite ? FAVORITE_SELECT : GALLERY_SELECT;

    final fav =
        document.querySelector("body > div.ido > form > p")?.text?.trim() ?? "";
    debugPrint("num  $fav");

    // 画廊列表
    List<dom.Element> gallerys = document.querySelectorAll(select);

    debugPrint("gallerys.len  ${gallerys.length}");

    List<GalleryItemBean> gallaryItems = [];

    for (int i = 0; i < gallerys.length; i++) {
      var tr = gallerys[i];

      final category = tr.querySelector('td.gl1c.glcat > div')?.text?.trim();

      // 表头或者广告
      if (category == null || category.isEmpty) {
        continue;
      }

      final title =
          tr.querySelector('td.gl3c.glname > a > div.glink')?.text?.trim();

      final url =
          tr.querySelector('td.gl3c.glname > a')?.attributes['href'] ?? '';

//      debugPrint(url);
      RegExp urlRex = new RegExp(r"/g/(\d+)/(\w+)/$");
      var urlRult = urlRex.firstMatch(url);
//      debugPrint('gid ${urlRult.group(1)}  token ${urlRult.group(2)}');

      final gid = urlRult.group(1);
      final token = urlRult.group(2);

      // tags
      // todo 是否翻译tag
      final bool _enableTagTran = StorageUtil().getBool(ENABLE_TAG_TRANSLAT);
      final List<String> simpleTags = [];
      List tags = tr.querySelectorAll('div.gt');
      for (var tag in tags) {
        var tagText = tag.text.trim();
        simpleTags.add(_enableTagTran
            ? await EhTagDatabase.getTranTag(tagText) ?? tagText
            : tagText);
      }

      final img = tr.querySelector('td.gl2c > div > div > img');
      final imgDataSrc = img.attributes['data-src'];
      final imgSrc = img.attributes['src'];
      final imgUrl = imgDataSrc ?? imgSrc ?? '';

      // old
      final postTime =
          tr.querySelector('td.gl2c > div:nth-child(2) > div')?.text?.trim() ??
              '';

      /// old end
      GalleryItemBean galleryItemBean = new GalleryItemBean(
        gid: gid,
        token: token,
        englishTitle: title,
        imgUrl: imgUrl ?? '',
        url: url,
        category: category,
        simpleTags: simpleTags,
        postTime: postTime,
      );

      gallaryItems.add(galleryItemBean);
//      debugPrint(galleryItemBean.toString());
    }

    // 通过api请求获取更多信息
    if (gallaryItems.length > 0) {
      getMoreGalleryInfo(gallaryItems);
    }

    return gallaryItems;
  }
}