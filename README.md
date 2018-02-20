# pupil

pupil is a server that is made useful by how it uses the [morsel](https://www.github.com/krad/morsel) & [memento](https://www.github.com/krad/memento) libraries.

pupil can be used to create HLS streams from Audio & Video packets.

It does so by using the [morsel](https://www.github.com/krad/morsel) library.

It uploads those HLS streams to the cloud.

It also creates jpeg thumbnails of the stream at set keyframe intervals.

This is accomplished by using the [memento](https://www.github.com/krad/memento) library (a very thin wrapper around libavcodec for h264 decompression)

## Requirements

If building with memento support the following dependencies need to be installed.

  * libavcodec (57.107.100)
  * libavutil (55.78.100)
  * libswscale (4.8.100)
  * libswresample (2.9.100)

All of the above packages are available in ffmpeg release 3.4.1

## Configuring

pupil can be configured via a config file or environment variables.

Properties that need to be configured are:

  * `port` The port the server will run on
  * `root` The directory that pupil will create subdirectories in for writing media files
  * `bucket` The bucket that media files should be uploaded to
  * `keyID` The AWS key ID to use when uploading to the bucket
  * `keySecret` The AWS key secret to use when uploading to the bucket
  * `thumbnailInterval` How many key frames to count before creating a jpeg thumbnail of the stream

### Default values

  By default pupil's `port` will be set to `42000`

  It will treat the current working directory as it's `root`

  It will create a jpeg thumbnail every `30` keyframes

### File Configuration

  The project contains an `example.conf` file demonstrating how to set server values.

  If you wish to use a config file you have two options.

  * Have a file called config.json current working directory
  * Specify the path to the config file with a command line flag.

An example of using a file at a specific path:
```
pupil -c /path/to/config.json
```

### Environment Configuration

  You can set environment variables to configure pupil.

  Just run pupil normally and it will detect them.

  This makes working with things like Docker or OpsWorks very easy.

  Below are a list of the environment variables you should set:

   * `PUPIL_PORT`
   * `PUPIL_ROOT`
   * `PUPIL_BUCKET`
   * `PUPIL_THUMBNAIL_INTERVAL`
   * `AWS_REGION`
   * `AWS_KEYID`
   * `AWS_KEYSECRET`

These should all be fairly self explanatory.

## Roadmap

 * In future releases, memento support should become a build time option, so the ffmpeg libs won't be a hard requirement.
 * Pluggable support for different cloud providers.
