library;

const int defaultSearchRadiusMeters = 2000;

const Duration mapPollInterval = Duration(seconds: 12);

const Duration requestTimeout = Duration(seconds: 15);

const Duration locationTimeout = Duration(seconds: 10);

const Duration lastKnownPositionMaxAge = Duration(minutes: 2);

const String imagesBucket = 'product-images';

const int logoMaxSidePixels = 512;

const int maxUploadBytes = 5 * 1024 * 1024;
