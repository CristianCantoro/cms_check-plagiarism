#!/usr/bin/env python3

import os
import csv
import copy
import tqdm
import json
import regex
import zipfile
import pathlib

import argparse
from argparse import ArgumentTypeError

from collections import namedtuple
from collections import defaultdict

# globals
CLUSTER_SIMILARITY_THRESHOLD = 0.5

# named tuples
Source = namedtuple('Source',
                    ['name', 'gid', 'nsub', 'score', 'ext']
                    )
Comparison = namedtuple('Comparison',
                        ['source1', 'source2', 'name']
                        )
GroupComparison = namedtuple('GroupComparison',
                             ['gid1', 'gid2', 'name']
                             )
MatchingGroups = namedtuple('MatchingGroups',
                            ['gid1', 'gid2', 'similarity', 'filename']
                            )

# regexes
# --- example: sub77_8_95.0_.cpp-sub81_4_75.0_.cpp.json
FNAME_REGEX = regex.compile(
    r'sub([0-9]+)_([0-9]+)_([0-9\.]+|None)_(\..+)'
    )

FNAME_SINGLESUB_REGEX = regex.compile(
    rf'({FNAME_REGEX.pattern})-({FNAME_REGEX.pattern}).json'
    )
FNAME_GROUPED_REGEX = regex.compile(
    r'([0-9]+)-([0-9]+).json'
    )
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


# Extract a specific file from a zip archive and keep it in memory
def extract_zip(zip_file, exclude=[]):
    zip_contents = {}

    with zipfile.ZipFile(zip_file, 'r') as zip_ref:
        # get a list of all the files in the zip file
        file_list = zip_ref.namelist()
        
        # iterate over the file list and extract each file that is not in the
        # exclude list
        for file_name in file_list:
            if file_name not in exclude:
                file_contents = zip_ref.read(file_name)
                zip_contents[file_name] = json.loads(file_contents)

    return zip_contents


def parse_name_singlesub(filename):
    match = FNAME_SINGLESUB_REGEX.match(filename)

    # match should not be None and it should contain 10 groups
    assert match and len(match.groups()) == 10, \
        "Filename did not match regex"

    groups = match.groups()

    name1, name2 = groups[0], groups[5] 
    gid1, gid2 = int(groups[1]), int(groups[6])
    nsub1, nsub2 = int(groups[2]), int(groups[7])

    # score can be None
    score1 = float(groups[3]) if groups[3] != 'None' else None
    score2 = float(groups[8]) if groups[8] != 'None' else None
    ext1, ext2 = groups[4], groups[9]

    comp = Comparison(Source(name1, gid1, nsub1, score1, ext1),
                      Source(name2, gid2, nsub2, score2, ext2),
                      filename)

    return comp


def parse_name_grouped(filename):
    match = FNAME_GROUPED_REGEX.match(filename)

    # match should not be None and it should contain 10 groups
    assert match and len(match.groups()) == 2, \
        "Filename did not match regex"

    gid1, gid2 = match.groups()
    group_comp = GroupComparison(gid1, gid2, filename)
    
    return group_comp


def select_excluded_files(zip_archive, grouped=False):
    # read zip archive
    archive = zipfile.ZipFile(zip_archive, 'r')

    # keep the json files (i.e. they end with '.json')
    # also, ignore the overview.json file
    all_results_filenames = set(
        f for f in archive.namelist()
        if f.endswith('.json') and f != 'overview.json'
        )

    # parse file names
    parsed_results_names = {}
    for filename in all_results_filenames:
        if not grouped:
            parsed_results_names[filename] = parse_name_singlesub(filename)

    # exclude same group comparisons
    same_group_filenames = set()
    if not grouped:
        for filename in all_results_filenames:
            comparison = parsed_results_names[filename]
            if comparison.source1.gid == comparison.source2.gid:
                same_group_filenames.add(comparison.name)

    excluded_filenames = (set(archive.namelist())
                          .difference(all_results_filenames)
                          .union(same_group_filenames)
                          )

    return excluded_filenames


def extract_comparisons(zip_archive, grouped=False):
    excluded_filenames = select_excluded_files(args.JPLAG_RESULTS,
                                               grouped=grouped)
    zip_contents = extract_zip(args.JPLAG_RESULTS,
                               exclude=excluded_filenames)

    return zip_contents


def select_max_similarity_between_groups(comparisons, grouped=False):
    parsed_comparisons = defaultdict(MatchingGroups)
    for filename, similarity in comparisons:
        if not grouped:
            comp = parse_name_singlesub(filename)

            # group with the smaller id first
            gid1 = comp.source1.gid
            gid2 = comp.source2.gid
            key = (gid1, gid2) if gid1 < gid2 else (gid2, gid1)
        else:
            comp = parse_name_grouped(filename)
            gid1 = comp.gid1
            gid2 = comp.gid2
            key = (gid1, gid2) if gid1 < gid2 else (gid2, gid1)

            # gid1, gid2, similarity, filename
            new_mgroups = MatchingGroups(key[0], key[1], similarity, filename)

            old_mgroups = (parsed_comparisons
                           .get(key, MatchingGroups(-1, -1, 0.0, ''))
                           )
            if new_mgroups.similarity > old_mgroups.similarity:
                parsed_comparisons[key] = new_mgroups

    return parsed_comparisons


def all_elements_same(lst):
    if len(lst) == 0:
        return True
    first_element = lst[0]
    for element in lst:
        if element != first_element:
            return False
    return True


def select_clusters(clusters, sim_threshold, grouped=False):
    selected_clusters = []
    for cluster in clusters:
        avg_similarity = cluster['avg_similarity']
        members_list = sorted(cluster['members'])

        members = []
        if not grouped:
            for member in members_list:
                sp_match = FNAME_REGEX.match(member)
                assert sp_match is not None

                gid = int(sp_match.group(1))
                nsub = int(sp_match.group(2))
                score = float(sp_match.group(3))

                members.append((gid, score, nsub, member))
        else:
            members = [int(m) for m in members_list]

        # sort by gid, then score and nsub (single subs) or 
        # sort by group
        members.sort()

        if avg_similarity >= sim_threshold:
            new_cluster = copy.copy(cluster)
            # if we are considering single subs, exclude the case where all
            # the subs come from the same group.
            if not grouped and \
                    not all_elements_same([m[0] for m in members]):

                new_cluster['groups'] = sorted(set([m[0] for m in members]))
                selected_clusters.append(new_cluster)

            if grouped:
                new_cluster['groups'] = members
                selected_clusters.append(new_cluster)

    return selected_clusters


# parse CLI args with argparse
def cli_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('JPLAG_LOG',
                        type=PathType(exists=True, type='file'),
                        help='Jplag log file.')
    parser.add_argument('JPLAG_RESULTS',
                        type=PathType(exists=True, type='file'),
                        help='Jplag results in zip format.')
    parser.add_argument('-g', '--grouped',
                        action='store_true',
                        help="Submissions are analyzed grouped.")
    parser.add_argument('-o', '--output',
                        type=pathlib.Path,
                        default=None,
                        help="Base name for report fiiles "
                             "[default: JPLAG_LOG].")
    parser.add_argument('-s', '--similarity',
                        type=float,
                        default=None,
                        help="Similarity threshold [default: 0.33].")

    args = parser.parse_args()

    return args


if __name__ == '__main__':
    args = cli_args()

    with args.JPLAG_LOG.open('r') as logfp:
        log_data = [line.strip() for line in logfp.readlines()]

    comparisons = extract_comparisons(args.JPLAG_RESULTS,
                                      grouped=args.grouped)
    sorted_comparisons = [(k, v['similarity']) for k, v
                          in sorted(comparisons.items(),
                                    key=lambda item: item[1]['similarity'],
                                    reverse=True
                                    )
                          ]
    max_similarity = select_max_similarity_between_groups(sorted_comparisons,
                                                          args.grouped)
    max_similarity_sorted = [group for group
                             in sorted(max_similarity.items(),
                                       key=lambda item: item[1].similarity,
                                       reverse=True
                                       )
                             ]

    if args.similarity:
        selected_groups = [group for key, group in max_similarity_sorted
                           if group.similarity > args.similarity]
    else:
        selected_groups = [group for key, group in max_similarity_sorted[:10]]

    comp_output_file = None
    if args.output:
        comp_output_file = args.output.with_name(
            args.output.stem + '_report.csv'
            )
    else:
        comp_output_file = args.JPLAG_LOG.with_name(
            args.JPLAG_LOG.stem + '_report.csv'
            )
    with comp_output_file.open('w') as comp_outfp:
        csvwriter = csv.writer(comp_outfp, delimiter='\t')

        # write header
        csvwriter.writerow(['gid1', 'gid2', 'similarity', 'filename'])

        for group in selected_groups:
            csvwriter.writerow(group)

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

    cluster_similarity = args.similarity \
        if args.similarity else CLUSTER_SIMILARITY_THRESHOLD
    selected_clusters = select_clusters(clusters,
                                        cluster_similarity,
                                        args.grouped)

    clusters_output_file = None
    if args.output:
        clusters_output_file = args.output.with_name(
            args.output.stem + '_clusters_report.csv'
            )
    else:
        clusters_output_file = args.JPLAG_LOG.with_name(
            args.JPLAG_LOG.stem + '_clusters_report.csv'
            )
    with clusters_output_file.open('w') as clusters_outfp:
        csvwriter = csv.writer(clusters_outfp, delimiter='\t')

        # write header
        if not args.grouped:
            csvwriter.writerow(['groups', 'strength', 'avg_similarity',
                                'members'])
        else:
            # cluster members are redundant for groups, they are the groups
            # again
            csvwriter.writerow(['groups', 'strength', 'avg_similarity'])

        for cluster in selected_clusters:
            groups = ','.join([str(el) for el in cluster['groups']])
            strength = cluster['strength']
            avg_similarity = cluster['avg_similarity']

            if not args.grouped:
                members = ','.join([str(el) for el in cluster['members']])
                csvwriter.writerow([groups, strength, avg_similarity,
                                    members])
            else:
                csvwriter.writerow([groups, strength, avg_similarity])

    exit(0)
