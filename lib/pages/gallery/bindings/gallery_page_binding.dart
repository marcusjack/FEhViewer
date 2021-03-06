import 'package:fehviewer/common/service/depth_service.dart';
import 'package:fehviewer/models/index.dart';
import 'package:fehviewer/pages/gallery/controller/archiver_controller.dart';
import 'package:fehviewer/pages/gallery/controller/comment_controller.dart';
import 'package:fehviewer/pages/gallery/controller/gallery_page_controller.dart';
import 'package:fehviewer/pages/gallery/controller/rate_controller.dart';
import 'package:fehviewer/pages/gallery/controller/torrent_controller.dart';
import 'package:get/get.dart';

class GalleryBinding extends Bindings {
  GalleryBinding.fromUrl(this.url);
  GalleryBinding.fromItem(this.tabIndex, this.galleryItem);
  String url;

  String tabIndex;
  GalleryItem galleryItem;

  @override
  void dependencies() {
    // logger.d('GalleryBinding dependencies');

    if (url != null) {
      Get.put(GalleryPageController.initUrl(url: url), tag: pageCtrlDepth);
    } else if (galleryItem != null) {
      Get.put(
        GalleryPageController.fromItem(
          galleryItem: galleryItem,
          tabIndex: tabIndex,
        ),
        tag: pageCtrlDepth,
      );
    }
    Get.lazyPut(
      () => CommentController(
          pageController: Get.find<GalleryPageController>(tag: pageCtrlDepth)),
      tag: pageCtrlDepth,
    );

    Get.lazyPut<RateController>(
        () => RateController(
            pageController:
                Get.find<GalleryPageController>(tag: pageCtrlDepth)),
        tag: pageCtrlDepth);

    Get.lazyPut<TorrentController>(
        () => TorrentController(
            pageController:
                Get.find<GalleryPageController>(tag: pageCtrlDepth)),
        tag: pageCtrlDepth);

    Get.lazyPut<ArchiverController>(
        () => ArchiverController(
            pageController:
                Get.find<GalleryPageController>(tag: pageCtrlDepth)),
        tag: pageCtrlDepth);
  }
}
