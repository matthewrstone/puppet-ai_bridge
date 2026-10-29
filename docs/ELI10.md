# ai_bridge, explained like you're 10

## The problem

Imagine Puppet Enterprise is a kid who only knows how to order one thing at a restaurant: "I'll have the o4-mini, please." It's the only words it knows. It's been saying it for ages and it always worked.

One day the restaurant (OpenAI) takes o4-mini off the menu. Now every time PE says "I'll have the o4-mini," the waiter says "Sorry, we don't serve that anymore," and PE just stands there confused with a red error banner on its forehead.

PE can't learn new words. The people who built it didn't give it a box to type a different dish name — only a box for *which restaurant* to go to and a *membership card* (the API key).

## The trick

Since we can pick the restaurant, we build our own tiny restaurant called **ai_bridge** and tell PE to go there instead.

Our restaurant has a very friendly waiter (a program called LiteLLM). When PE walks in and says "I'll have the o4-mini," our waiter says "Of course!" — and then quietly walks into the kitchen and orders whatever we told him to:

- a Claude dish from Anthropic's kitchen,
- a newer dish from OpenAI's kitchen (gpt-5-mini),
- or something cooked right here at home on your own computer (Ollama, vLLM).

The waiter brings the food back on an "o4-mini" plate. PE eats it happily and never knows the difference.

## Why it's safe

- PE still shows its membership card at the door. Our waiter checks it (the **master key**). No card, no service.
- The *real* kitchen keys (the Anthropic or OpenAI key) stay locked in our waiter's pocket. PE never sees them.
- The restaurant has a proper lock on the door (TLS), so nobody can listen in on the orders.
- The waiter can't leave the restaurant, change the furniture, or run as the manager (the container is read-only, runs as a normal user, with no special powers).

## What the Puppet module does

Puppet is the builder. You give it a blueprint (Hiera data) that says which kitchen to use and hand it the keys in a sealed envelope (encrypted). Puppet builds the restaurant, hires the waiter, locks the door, and keeps checking every 30 minutes that everything is still exactly as the blueprint says.

Want to switch from Claude to a local model? Change one line in the blueprint. Puppet rebuilds the kitchen door. PE never notices.

## What pe-capture is

Before we opened the real restaurant we built a fake one with a notebook. PE walked in, said its order, and we wrote down *exactly* what it said and how it said it. That way we know for sure what our real waiter needs to understand. Nobody likes guessing.
