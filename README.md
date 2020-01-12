# Libvirt Web

## Development

### Install
```bash
gem install ext/ruby-libvirt-0.7.2.pre.streamfix3.2.gem
bundle install
```

### Run
```bash
bundle exec falcon serve -b http://localhost -p 4567 -n 1 --threaded
```

### Update custom ruby-libvirt package
1. replace gem in `ext/`
1. copy gem to `vendor/cache/`
1. change version in Gemfile
1. run `bundle update ruby-libvirt --conservative`
