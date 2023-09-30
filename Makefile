ZIO_TEMPORAL_VERSION = 0.6.0
ZIO_VERSION          = 2.0.18

.PHONY: help
# target: help - Display callable targets
help:
	@egrep "^# target:" [Mm]akefile

.PHONY: hugo-dev
hugo-dev:
	hugo server -b http://localhost:1313/

.PHONY: mdoc
mdoc:
	coursier launch org.scalameta:mdoc_2.13:2.3.7 -- \
	--site.VERSION 1.0.0 \
	--classpath $$( \
		cs fetch -p \
		  dev.vhonta:zio-temporal-core_2.13:$(ZIO_TEMPORAL_VERSION) \
		  dev.vhonta:zio-temporal-protobuf_2.13:$(ZIO_TEMPORAL_VERSION) \
		  dev.zio:zio_2.13:$(ZIO_VERSION) \
		  dev.zio:zio-streams_2.13:$(ZIO_VERSION) \
		  dev.zio:zio-nio_2.13:2.0.2 \
          com.google.api-client:google-api-client:2.2.0 \
          com.google.apis:google-api-services-youtube:v3-rev20230502-2.0.0 \
	) \
	--in mdoc/input/$(POST_NAME).md \
	--out content/posts
