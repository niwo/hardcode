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

Scan a directory for multimedia file, move them to the tmp directory and enqueue transcoding jobs if needed:

```bash
hardcode enqueue /home/media/import --destination /var/www/videos
```

### Example: Start the workers

Starts the sneakers based workers which will wait for transcoding jobs coming from the RabbitMQ queue:

```bash
hardcode work --debug
```

## Running the worker in production

Put the following systemd configuration under /usr/lib/systemd/system/hardcode-worker.service (for RHEL/CentOS 7) and adapt it to your needs:

```
[Unit]
Description=Hardcode Worker
After=syslog.target
After=network.target
After=rabbitmq-server.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/hardcode work

# Give a reasonable amount of time for the workers to start up/shut down
TimeoutSec=300

[Install]
WantedBy=multi-user.target
```

Start the workers using systemd and enable it at boottime:

```bash
systemctl start hardcode-worker.service
systemctl enable hardcode-worker.service
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/hardcode/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
