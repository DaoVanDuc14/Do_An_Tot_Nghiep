import 'dart:io';
import 'package:image/image.dart';

void main() {
  final bytes = File('lib/data/images/logo_khong_nen.png').readAsBytesSync();
  final img = decodeImage(bytes);
  if (img == null) {
    print('Failed to decode image');
    return;
  }
  
  int newSize = (img.width * 1.5).round();
  
  // Create a new blank image
  final newImg = Image(width: newSize, height: newSize);
  
  // Fill the padding with the EXACT background color of the splash screen (#0A1628)
  // R: 0x0A (10), G: 0x16 (22), B: 0x28 (40), A: 255
  fill(newImg, color: ColorRgba8(10, 22, 40, 255));
  
  // Calculate center position
  int dx = (newSize - img.width) ~/ 2;
  int dy = (newSize - img.height) ~/ 2;
  
  // Paste original image into the center
  compositeImage(newImg, img, dstX: dx, dstY: dy);
  
  File('lib/data/images/logo_native_splash.png').writeAsBytesSync(encodePng(newImg));
  print('Image padded with background color #0A1628 and saved!');
}
