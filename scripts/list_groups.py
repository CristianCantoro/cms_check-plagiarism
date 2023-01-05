#!/usr/bin/env python
"""
List groups from Jplag report.

Usage:
  list_groups.py <report>
  list_groups.py (-h | --help)
  list_groups.py --version

Options:
  -h --help     Show this screen.
  --version     Show version.
"""
import re
import sys
import argparse

# globals
LINE_FORMAT=r'Comparing (.+?)-(.+?): ([0-9]+\.[0-9]+)'
LINE_REGEX = re.compile(LINE_FORMAT)

SUB_FORMAT=r'sub([0-9]+)_([0-9]+)_([0-9]+\.[0-9]+)_.cpp'
SUB_REGEX = re.compile(SUB_FORMAT)

GROUP_DATA = ('gid', 'sub', 'points')


# parse CLI args with argparse
def cli_args(file=sys.stdout):
    parser = argparse.ArgumentParser()

    parser.add_argument("JPLAG_REPORT",
                        help="Jplag clean report file.")
    args = parser.parse_args()

    return args


def get_group_data(data_match):
    res = data_match.groups()
    gid = int(res[0])
    sub = int(res[1])
    points = float(res[2])

    return dict(zip(GROUP_DATA, (gid, sub, points)))


if __name__ == '__main__':

    args = cli_args()
    jplag_report=args.JPLAG_REPORT

    with open(jplag_report, 'r') as infile:
        report = [line.strip() for line in infile.readlines()]

    for line in report:
        match = LINE_REGEX.match(line)
        if match:
            g1_data = match.groups()[0]
            g2_data = match.groups()[1]
            sim = match.groups()[2]

            g1 = get_group_data(SUB_REGEX.match(g1_data))
            g2 = get_group_data(SUB_REGEX.match(g2_data))

            if g1['gid'] != g2['gid']:
                # 10 (3@40.0) -> 11 (22@100.0): 4.9800797
                print('{gid1} ({sub1}@{points1}) -> '
                      '{gid2} ({sub2}@{points2}): '
                      '{sim}'
                      .format(gid1=g1['gid'],
                              sub1=g1['sub'],
                              points1=g1['points'],
                              gid2=g2['gid'],
                              sub2=g2['sub'],
                              points2=g2['points'],
                              sim=sim
                              )
                      )
    exit(0)