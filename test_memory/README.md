mkdir -p vendor/bundle vendor/cache
cp ext/*.gem vendor/cache
GEM_HOME=vendor/cache gem3.0 install bundler --no-doc
GEM_HOME=vendor/cache BUNDLE_PATH=vendor/bundle i -j16

ruby3.0 -Itest test_memory/screenshot_test.rb
