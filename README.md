# ProducerQueue

## Installation

Published to the private `flickswitch` hex repository, not to hex.pm. Register the
repository once per machine — it is private, so reads need the auth token, ask SRE
(this is the read token, not the publish token):

```sh
curl -sS https://hex.flickswitch.cloud/repos/flickswitch/public_key -o /tmp/flickswitch_hex_public_key.pem
mix hex.repo add flickswitch https://hex.flickswitch.cloud/repos/flickswitch \
  --public-key /tmp/flickswitch_hex_public_key.pem --auth-key <read-token>
```

Then add the dependency:

```elixir
def deps do
  [
    {:producer_queue, "~> 5.0", repo: "flickswitch"}
  ]
end
```

