# (EN) Plagiarism check for CMS

A collection of scripts to check plagiarism for contests on [CMS](https://github.com/cms-dev/cms).

```
Usage:
  check_plagiarism.sh [options] [ --jplag JPLAG_JAR ]
    [ --sherlock SHERLOCK_BIN ]
  check_plagiarism.sh ( -h | --help | --man )
  check_plagiarism.sh ( --version )

  Options:
    -d, --debug                   Enable debug mode (implies --verbose)
    -h, --help                    Show this help message and exits.
    --jplag JPLAG_JAR             Path to JPLAG's JAR (w/ deps)
                                  [default: /opt/jplag/jplag.jar]
    --sherlock SHERLOCK_BIN       Path to sherlock's binary
                                  [default: /home/cristian/bin/sherlock]
    --man                         Show an extended help message.
    -v, --verbose                 Generate verbose output.
    --version                     Print version and copyright information
```

## Usage

To check sources for plagiarism simply do:
```
./check_plagiarism.sh
```

This script assumes the following:
  * a folder called 'allsrc' is located in the current directory
  * JPLAG JAR is located at '/opt/jplag/jplag.jar'
  * sherlock's binary is in your PATH

## Dependencies

This script has the following dependencies:

  * docopts, `v0.6.1+fix`
    download at: https://github.com/docopt/docopts

  * sherlock
    download at: http://www.cs.usyd.edu.au/~scilect/sherlock/

  * JPLAG, `v2.11.X`
    download the jar with dependencies at: https://github.com/jplag/jplag
