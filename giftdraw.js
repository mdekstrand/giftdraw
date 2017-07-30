const args = require('yargs')
    .usage('Usage: $0 -t [template] -f [file]')
    .boolean('v')
    .describe('v', 'be verbose')
    .boolean('t')
    .describe('t', 'specify a template to use')
    .describe('send-to', 'send all messages to EMAIL instead of recipient')
    .help('h')
    .alias('h', 'help')
    .argv;