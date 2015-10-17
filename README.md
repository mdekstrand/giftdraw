This program draws names for a gift drawing.  It randomly pairs people from a list of family members
and e-mails each one with their matched gift recipient.

It requires a few things:

- Python 3 (tested on 3.4)
- `requests` (`pip install requests`)
- A [Mailgun][mg] account.

[mg]: http://mailgun.com

With these in place, you need to create a few configuration files.

First, the main configuration file, `giftdraw.cfg`:

```
[mailgun]
mailbox = <mailgun domain>
sender = Gift Drawing <giftdraw@ekstrandom.net>
key = <mailgun key>

[mail]
subject = <email subject>
cc = <optional CC person to receive copies of all assignments>
```

Second, a file to configure the list of family members, `family.cfg`:

```sh
person "Alice" "alice@example.com"
person "Bob" "bob@example.com"
person "Carol" "carol@example.com"
person "Eve" "eve@example.org"
```

Thirdly, you need an e-mail template, `email.txt`:

```
Dear $giver,

The Gift Assignment Combobulator has now been
run, and you have drawn $recipient.

- Evil Robot
```

With all these pieces in place, you can run it!

```
python3 giftdraw.py family.cfg
```

There are additional options, run with `--help` to see them.
