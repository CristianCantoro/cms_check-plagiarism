#!/usr/bin/env python3

import os
import regex
import pathlib

import argparse
from argparse import ArgumentTypeError


SIMILARITY_THRESHOLD = 0.9

# regexes
CLUSTERING_REGEX = regex.compile(
    r'^.+ \[main\] \[INFO\] ClusteringFactory - .+$'
    )
NCLUSTERS_REGEX = regex.compile(
    r'^.+ \[main\] \[INFO\] ClusteringFactory - ([0-9]+) clusters were found:$'
    )
CLUSTERS_PARAM_REGEX = regex.compile(
    r'^.+ \[main\] \[INFO\] ClusteringFactory -  cluster strength: ([0-9\.E\-]+), '
    r'avg similarity: ([0-9\.E\-]+)%, members: \[(.+)\]$'
    )
SRC_PARAM_REGEX = regex.compile(r'sub[0-9]+_([0-9]+)_([0-9\.]+)_\..+')


class PathType(object):
    def __init__(self, exists=True, type='file', dash_ok=True):
        '''exists:
             - True: a path that does exist
             - False: a path that does not exist, in a valid parent directory
             - None: don't care
           type: file, dir, symlink, None, or a function returning:
             - True for valid paths
             - None: don't care
           dash_ok: whether to allow "-" as stdin/stdout'''

        assert exists in (True, False, None)
        assert (type in ('file', 'dir', 'symlink', None) or
                hasattr(type, '__call__'))

        self._exists = exists
        self._type = type
        self._dash_ok = dash_ok

    def __call__(self, string):
        if string == '-':
            # the special argument "-" means sys.std{in,out}
            if self._type == 'dir':
                raise ArgumentTypeError('standard input/output (-) not allowed as directory path')
            elif self._type == 'symlink':
                raise ArgumentTypeError('standard input/output (-) not allowed as symlink path')
            elif not self._dash_ok:
                raise ArgumentTypeError('standard input/output (-) not allowed')
        else:
            e = os.path.exists(string)
            if self._exists:
                if not e:
                    raise ArgumentTypeError("path does not exist: '%s'" % string)

                if self._type is None:
                    pass
                elif self._type == 'file':
                    if not os.path.isfile(string):
                        raise ArgumentTypeError("path is not a file: '%s'" % string)
                elif self._type == 'symlink':
                    if not os.path.symlink(string):
                        raise ArgumentTypeError("path is not a symlink: '%s'" % string)
                elif self._type == 'dir':
                    if not os.path.isdir(string):
                        raise ArgumentTypeError("path is not a directory: '%s'" % string)
                elif not self._type(string):
                    raise ArgumentTypeError("path not valid: '%s'" % string)
            else:
                if not self._exists and e:
                    raise ArgumentTypeError("path exists: '%s'" % string)

                p = os.path.dirname(os.path.normpath(string)) or '.'
                if not os.path.isdir(p):
                    raise ArgumentTypeError("parent path is not a directory: '%s'" % p)
                elif not os.path.exists(p):
                    raise ArgumentTypeError("parent directory does not exist: '%s'" % p)

        return pathlib.Path(string)


def select_cluster_members(cluster):
    avg_similarity = cluster['avg_similarity']
    members_list = sorted(cluster['members'])

    members = []
    for member in members_list:

        sp_match = SRC_PARAM_REGEX.match(member)
        assert sp_match is not None

        nsub = int(sp_match.group(1))
        score = float(sp_match.group(2))

        members.append((score, nsub, member))

    # sort by score and then nsub
    members.sort()

    selected_sources = members_list
    if avg_similarity >= SIMILARITY_THRESHOLD:
        # get the first element that has a score greater than 0
        #   https://noclick.dev/get-first-item
        # if all the elements have score 0, then take the first one, i.e.
        # the earlier sub
        first_match = next(
            (m for m in members if m[0] > 0),
            members[0]
        )
        selected_sources = [first_match[2]]
    else:
        selected_sources = [m[2] for m in members]

    return selected_sources


# parse CLI args with argparse
def cli_args():
    parser = argparse.ArgumentParser()

    parser.add_argument("JPLAG_LOG",
                        type=PathType(exists=True, type='file'),
                        help="Jplag log file.")
    parser.add_argument("SOURCES_DIR",
                        type=PathType(exists=True, type='dir'),
                        help="Directory with submissions sources.")

    args = parser.parse_args()

    return args


if __name__ == '__main__':
    args = cli_args()

    files = [file for file in args.SOURCES_DIR.iterdir()]
    all_sources = set(f.name for f in files)

    with args.JPLAG_LOG.open('r') as logfp:
        log_data = [line.strip() for line in logfp.readlines()]

    nclusters = 0
    clusters = []
    # parse cluster data from JPLAG logs
    for line in log_data:
        if CLUSTERING_REGEX.match(line):

            nclusters_match = NCLUSTERS_REGEX.match(line)
            if nclusters_match:
                nclusters = nclusters_match.group(1)
            else:
                cp_match = CLUSTERS_PARAM_REGEX.match(line)
                if cp_match:
                    # print("--", line)
                    cl_strength = float(cp_match.group(1))
                    cl_avg_similarity = float(cp_match.group(2))
                    cl_members = set(cm.strip() for cm
                                     in cp_match.group(3).strip().split(','))

                    clusters.append({'strength': cl_strength,
                                     'avg_similarity': cl_avg_similarity,
                                     'members': cl_members
                                     })

    selected_sources = set()
    all_clusters_members = set()
    for cl in clusters:
        sel_sources = select_cluster_members(cl)
        selected_sources.update(set(sel_sources))

        all_clusters_members.update(cl['members'])

    # all selected sources contains:
    #  - all sources that are not part of a cluster
    #      (all_sources - all_clusters_members)
    #  - the sources selected as representatives of a cluster
    all_selected_sources = (all_sources
                            .difference(all_clusters_members)
                            .union(selected_sources))

    # retrieve the path of the selected soruces
    all_selected_files = sorted(f for f in files
                                if f.name in all_selected_sources)

    for selected_file in all_selected_files:
        print(selected_file)

    exit(0)
