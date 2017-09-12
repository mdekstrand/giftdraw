"""
Gift drawing script.

Copyright © 2015 Michael Ekstrand

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the “Software”), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
"""

import sys
import shlex
import argparse
from string import Template
import random
from configparser import ConfigParser
import requests


class Person(object):
    def __init__(self, name, email):
        self.name = name
        self.email = email

    def __str__(self):
        return "{} <{}>".format(self.name, self.email)


def read_family(f):
    people = []
    blocks = set()
    lex = shlex.shlex(f, posix=True)
    tok = lex.get_token()
    while tok is not None:
        if tok == u'person':
            name = lex.get_token()
            email = lex.get_token()
            person = Person(name, email)
            people.append(person)
            print('Loaded person {}'.format(person))
        elif tok == u'block':
            em1 = lex.get_token()
            em2 = lex.get_token()
            blocks.add((em1, em2))
            blocks.add((em2, em1))
        else:
            print('Unexpected token {}'.format(tok),
                  file=sys.stderr)
        tok = lex.get_token()

    blocks |= set((p1.email, p1.email) for p1 in people)

    return (people, blocks)


def draw_names(fam, blocks):
    while True:
        f2 = fam.copy()
        random.shuffle(f2)
        alloc = list(zip(fam, f2))
        if any((g.email, r.email) in blocks for g,r in alloc):
            print('could not draw names, trying again', file=sys.stderr)
        else:
            return alloc


def send_mails(alloc, template, config, send_to=None, verbose=True):
    mbsec = config['mailgun']
    key = mbsec['key']
    mailbox = mbsec['mailbox']
    sender = mbsec['sender']
    subject = config['mail']['subject']
    cc = config['mail'].get('cc')
    reply = config['mail'].get('reply')
    for giver, recip in alloc:
        if verbose:
            print("{} giving to {}".format(giver, recip))
        mail = template.substitute(giver=giver.name, email=giver.email,
                                   recipient=recip.name)
        actual_recip = giver if send_to is None else send_to
        params = {"from": sender,
                  "to": [actual_recip],
                  "subject": subject,
                  "text": mail}
        if reply is not None:
            params['h:Reply-To'] = reply
        if cc is not None and actual_recip is None:
            params['cc'] = [cc]
        requests.post(
            "https://api.mailgun.net/v3/{}/messages".format(mailbox),
            auth=("api", key),
            data=params)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file', metavar='FILE', help='load from FILE')
    ap.add_argument ('-t', '--template', metavar='FILE',
                     help='load email template from FILE',
                     dest='template', default='email.txt')
    ap.add_argument('-v', '--verbose', action='store_true', dest='verbose',
                    default=False)
    ap.add_argument('-c', '--config', dest='config', default='giftdraw.cfg',
                    help='specify configuration file for giftdraw operation')
    ap.add_argument('--send-to', dest='send_to', metavar='EMAIL',
                    help='send all messages to EMAIL instead of recipient (for debugging)')
    args = ap.parse_args()
    config = ConfigParser()
    config.read(args.config)
    with open(args.file) as f:
        family, blocks = read_family(f)
    with open(args.template) as f:
        template = Template(f.read())
    alloc = draw_names(family, blocks)
    send_mails(alloc, template, config, args.send_to, args.verbose)


if __name__ == '__main__':
    main()