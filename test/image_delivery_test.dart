import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/core/images/image_delivery.dart';

const plain =
    'https://res.cloudinary.com/dbwxnt91x/image/upload/v1712345/products/rice.jpg';

void main() {
  group('imagePixelWidth', () {
    test('snaps to shared cache buckets', () {
      expect(imagePixelWidth(84, 3), 320); // 252px thumbnail
      expect(imagePixelWidth(160, 2), 320);
      expect(imagePixelWidth(400, 3), 1280);
      expect(imagePixelWidth(5000, 3), 2560);
    });

    test('returns null for unknown sizes so the original is used', () {
      expect(imagePixelWidth(double.infinity, 3), isNull);
      expect(imagePixelWidth(0, 3), isNull);
      expect(imagePixelWidth(100, 0), isNull);
    });
  });

  group('optimizedImageUrl', () {
    test('adds format, quality and width to plain Cloudinary uploads', () {
      expect(
        optimizedImageUrl(plain, 640),
        'https://res.cloudinary.com/dbwxnt91x/image/upload/'
        'f_auto,q_auto,c_limit,w_640/v1712345/products/rice.jpg',
      );
    });

    test('leaves URLs it cannot safely rewrite unchanged', () {
      const unchanged = [
        // Already transformed (e.g. Image Studio output).
        'https://res.cloudinary.com/x/image/upload/e_trim/v1/a.png',
        'https://res.cloudinary.com/x/image/upload/w_200,h_200/v1/a.png',
        // Signed delivery URL.
        'https://res.cloudinary.com/x/image/upload/s--abc123--/v1/a.png',
        // Other hosts, videos, query strings, plain http.
        'https://naijago-backend.onrender.com/uploads/a.png',
        'https://res.cloudinary.com/x/video/upload/v1/a.jpg',
        'https://res.cloudinary.com/x/image/upload/v1/a.png?token=1',
        'http://res.cloudinary.com/x/image/upload/v1/a.png',
        'not a url',
        '',
      ];
      for (final url in unchanged) {
        expect(optimizedImageUrl(url, 640), url, reason: url);
      }
    });

    test('no width means no rewrite', () {
      expect(optimizedImageUrl(plain, null), plain);
    });

    test('preserves encoded public ids exactly', () {
      const encoded =
          'https://res.cloudinary.com/x/image/upload/v1/my%20folder/fresh%20tomato.jpg';
      expect(
        optimizedImageUrl(encoded, 320),
        'https://res.cloudinary.com/x/image/upload/f_auto,q_auto,c_limit,w_320/v1/my%20folder/fresh%20tomato.jpg',
      );
    });
  });
}
