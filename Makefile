SHELL := /bin/sh

pkg_name := virtualizm-api
user := virtualizm
app_dir := /opt/virtualizm
conf_dir := /etc/virtualizm
app_files :=	version.yml \
		app \
		bin \
		config \
		db \
		lib \
		public \
		config.ru \
		Gemfile \
		Gemfile.lock \
		Rakefile \
		vendor \
		.bundle

exclude_files := config/app.yml 

config_files := app.yml

export DEBFULLNAME ?= Virtualizm team
export DEBMAIL ?= team@virtualizm.org
debian_host_release != lsb_release -sc
commit = $(shell git rev-parse HEAD)
gems := $(CURDIR)/vendor/bundler
bundle_bin := $(gems)/bin/bundle
bundler_gems := $(CURDIR)/vendor/bundle
export GEM_PATH := $(gems):$(bundler_gems)

# debuild vars
debuild_env := http_proxy https_proxy SSH_AUTH_SOCK TRAVIS*
debuild_flags := $(foreach e,$(debuild_env),-e '$e') $(if $(findstring yes,$(lintian)),--lintian,--no-lintian)

### Rules ###
.PHONY: all


version.yml: debian/changelog
	$(info >>> Create version file)
	@echo "version: " $(shell dpkg-parsechangelog -S Version) > $@
	@echo "commit: " $(commit) >> $@
	cat $@


debian/changelog:
	$(info >>> Generating changelog)
	changelog-gen -p "$(pkg_name)" -d "$(debian_host_release)" -A "s/_/~/g" "s/-rc/~rc/"


.PHONY: bundler
bundler:
	$(info >>> Install bundler)
	gem install --no-doc --install-dir $(gems) bundler


.PHONY: gems
gems:	bundler
	$(info >>> Install/Update gems)
	$(bundle_bin) install --jobs=4 --deployment --without development test


.PHONY: install
install: $(app_files)
	$(info >>> Install app files)
	@install -vd $(DESTDIR)$(app_dir) $(DESTDIR)$(app_dir)/tmp $(DESTDIR)$(conf_dir)
	tar -c --no-auto-compress $(addprefix --exclude , $(exclude_files)) $^ | tar -x -C $(DESTDIR)$(app_dir)
	@install -v -m0644 -D debian/$(pkg_name).rsyslog $(DESTDIR)/etc/rsyslog.d/$(pkg_name).conf
	$(foreach f,$(config_files),ln -sTv $(conf_dir)/$f $(DESTDIR)$(app_dir)/config/$f;)


.PHONY: clean
clean:
	$(info >>> Cleaning)
	rm -rf $(gems)
	rm -rf $(bundler_gems)
	rm -rf .bundle
	rm -rf tmp


.PHONY: clean-all
clean-all:
	-@debian/rules clean
	@rm -fv version.yml
	@rm -fv debian/changelog


.PHONY: package
package: debian/changelog
	$(info >>> Building package)
	debuild $(debuild_flags) -uc -us -b

.PHONY: rspec
rspec: gems-test config/app.yml
ifdef spec
        $(info:msg=Testing spec $(spec))
        RAILS_ENV=test $(bundle_bin) exec rspec "$(spec)"
else
        $(info:msg=Running rspec tests)
        RAILS_ENV=test $(bundle_bin) exec parallel_test \
                  spec/ \
                  --type rspec \
                  $(if $(TEST_GROUP),--only-group $(TEST_GROUP),) \
                  && script/format_runtime_log log/parallel_runtime_rspec.log \
                  || { script/format_runtime_log log/parallel_runtime_rspec.log; false; }
endif

