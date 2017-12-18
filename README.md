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
  * a folder called 'allsrc' with all source files extracted from CMS is located in the current directory
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

## How it works

We assume that the folder `allsrc`, containing all source files submitted to CMS, is contained in the current folder. Intermediate output files are saved in a temporary folder created by `check_plagiarism.sh`.

1. All pairs of source files are checked against each other with sherlock using the script `allpairs.rb`, the output is saved as `allpairs.out`. The final result is saved as `plagiarism_report.sherlock.txt`

2. A selection of source files is checked using JPLAG:
   a. the script `tojplag.sh` select some source files (performing a clustering for the files submitted by each user with the script `clustering.rb`). Files are saved in the folfer `tojplag/`.
   b. JPLAG is executed on the `tojplag/` folder with the following parameters:
```
   java -jar jplag.jar -m 1000 -l c/c++ -r results tojplag
```
      intermediate results are written in `jplag.log`.
   c. the results of the similarity check performed by JPLAG between different users are listed by `list_groups.sh`

The final result is saved as `plagiarism_report.jplag.txt`
