# Hardcode

[stack-encode](https://github.com/swisstxt/stack-encode) on steroids (using a rabbitmq worker queue)

## Installation

Install the gem:

    $ gem install hardcode

## Dependencies

- ruby >= 2.0
- RabbitMQ
- lsof

## Usage

run `harcode help` for instructions

### Example: Enqueue Encoding Jobs to RabbitMQ

## Running the worker in production

Put the following systemd configuration under /usr/lib/systemd/system/hardcode.service (for RHEL/CentOS 7) and adapt it to your needs:

```
[Unit]
Description=Hardcode Worker
After=syslog.target
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=hardcode work

# Give a reasonable amount of time for the workers to start up/shut down
TimeoutSec=300

[Install]
WantedBy=multi-user.target
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/hardcode/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
