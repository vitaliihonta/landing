ZIO_TEMPORAL_VERSION = 0.4.0
ZIO_VERSION          = 2.0.16

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
	--classpath $$(cs fetch -p dev.vhonta:zio-temporal-core_2.13:$(ZIO_TEMPORAL_VERSION) dev.vhonta:zio-temporal-protobuf_2.13:$(ZIO_TEMPORAL_VERSION) dev.zio:zio_2.13:$(ZIO_VERSION)) \
	--in mdoc/input/$(POST_NAME).md \
	--out content/posts
