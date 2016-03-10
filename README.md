# FcrepoWrapper

Wrap any task with a Fcrepo instance:

```ruby
FcrepoWrapper.wrap do |solr|
  # Something that requires Fcrepo
end
```

## Basic Options

```ruby
FcrepoWrapper.wrap port: 8983, verbose: true, managed: true
```
