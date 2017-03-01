# DStatsD
![alt text](https://travis-ci.org/burner/dstatsd.svg?branch=master)

A fast, memory efficent, vibe.d compatible client for etsy's statsd.

```D
auto s = new StatsD("127.0.0.1", 1234, ""); // 

s(Counter("Foo")); // increment counter "Foo"
s.inc("Bar"); // increment counter "Bar"

s(Counter("Args"), 					// send stats to Args, H, and timeA 
	Counter("H", uniform(-10,10)),  // in one udp message
	Timer("timeA", uniform(12,260))
);
```

# Documentation
Please send Pull Requests. Currently, the source is the documentation.
