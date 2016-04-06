# FcrepoWrapper

Wrap any task with a Fcrepo instance:

```ruby
FcrepoWrapper.wrap do |solr|
  # Something that requires Fcrepo
end
```

## Configuration Options

### Command Line
To see a list of valid options when launching Fedora from the command line:
```
$ fcrepo_wrapper -h
```

### Ruby
```ruby
FcrepoWrapper.wrap port: 8983, verbose: true, managed: true
```

### Configuration file
FcrepoWrapper can read configuration options from a YAML configuration file.
By default, it will look for configuration files at `.fcrepo_wrapper` and `~/.fcrepo_wrapper`.

You can also specify a configuration file when invoking fcrepo_wrapper from the command line as follows:
```
$ fcrepo_wrapper -config <path_to_config_file>
```

### Valid ruby and YAML options
|Option         | Description                             |
|---------------|-----------------------------------------|
| instance_dir  | Directory to store the fedora data files |
| url           | URL of the jar file to download |
| version       | Fedora version to download and install |
| port          | port to run Fedora on |
| version_file  | Local path to store the currently installed version |
| download_path | Local path for storing the downloaded jar & md5 file |
| md5sum        | Path/URL to MD5 checksum |
| verbose       | (Boolean) return verbose info when running fcrepo commands (default: true) |
| validate      | (Boolean) download a new md5 and (re-)validate the jar file? (default: true) |
| ignore_md5sum | (Boolean) |
| fedora_options| (Hash) |
| env           | (Hash) |


