# FcrepoWrapper

Wrap any task with a Fcrepo instance:

```ruby
FcrepoWrapper.wrap do |solr|
  # Something that requires Fcrepo
end
```

## Configuration Options

### Command Line
To see a list of valid options when using fcrepo_wrapper to launch an Fcrepo instance from the command line:
```
$ fcrepo_wrapper -h
```

### Ruby
```ruby
FcrepoWrapper.wrap( port: 8983, verbose: true, managed: true )
```

### Configuration file
FcrepoWrapper can read configuration options from a YAML configuration file.
By default, it looks for configuration files at `.fcrepo_wrapper` and `~/.fcrepo_wrapper`.

You can also specify a configuration file when launching from the command line as follows:
```
$ fcrepo_wrapper -config <path_to_config_file>
```

### Valid ruby and YAML options
|Option           | Description                             |
|-----------------|-----------------------------------------|
| download_dir    | Local path for storing the downloaded jar & md5 file |
| env             | *(Hash)* |
| fcrepo_home_dir | Directory to store fedora repoistory data files |
| fedora_options  | *(Hash)* |
| ignore_md5sum   | *(Boolean)* suppress checksum error messages |
| instance_dir    | Directory to store the fedora jar file |
| md5sum          | Path/URL to MD5 checksum |
| port            | Port to run Fedora on |
| url             | URL of the jar file to download |
| validate        | *(Boolean)* download a new md5 and (re-)validate the jar file? (default: true) |
| verbose         | *(Boolean)* return verbose info when running fcrepo commands (default: false) |
| version         | Fedora version to download and install |
| version_file    | Local path to store the currently installed version number |

### Cleaning your repository from the command line

To clean out data that is being stored in you FcrepoWrapper explicitly run:
```
$ fcrepo_wrapper <configuration options> clean
```
***Note*** You must use the same configuration options on the clean command as you do on the run command to clean the correct instance.

