# ProducerQueue

## Installation

Published to the private `flickswitch` Hex repo. Add the repo once per machine
(reads are open, no auth token needed):

```sh
curl -sS https://hex.flickswitch.cloud/repos/flickswitch/public_key -o /tmp/flickswitch_hex_public_key.pem
mix hex.repo add flickswitch https://hex.flickswitch.cloud/repos/flickswitch --public-key /tmp/flickswitch_hex_public_key.pem
```

then in `mix.exs`:

```elixir
def deps do
  [
    {:producer_queue, "~> 5.0", repo: "flickswitch"}
  ]
end
```

