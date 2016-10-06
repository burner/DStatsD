import dstatsd;

import std.format : formattedWrite;
import std.internal.scopebuffer;

import vibe.core.core;
import vibe.core.net;

import fixedsizearray;

struct Counter {
	const string name;
	const long change;
	const double sampleRate;

	this(const string name, const long change = 1, 
			const double sampleRate = double.nan) 
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.change = change;
		this.sampleRate = sampleRate;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		import std.math : isNaN;
		if(this.sampleRate.isNaN()) {
			formattedWrite(buf, "%s%s:%s|c", prefix, this.name, this.change);
		} else {
			formattedWrite(buf, "%s%s:%s|c|@%f", prefix, this.name,
					this.change, this.sampleRate
			);
		}
	}
}

struct Gauge {
	const string name;
	const ulong value;

	this(const string name, const ulong value)
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.value = value;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		formattedWrite(buf, "%s%s:%s|g", prefix, this.name, this.value);
	}
}

struct Timer {
	const string name;
	const ulong time;

	this(const string name, const ulong time)
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.time = time;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		formattedWrite(buf, "%s%s:%s|ms", prefix, this.name, this.time);
	}
}

struct Histogram {
	const string name;
	const ulong value;

	this(const string name, const ulong value)
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.value = value;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		formattedWrite(buf, "%s%s:%s|h", prefix, this.name, this.value);
	}
}

struct Meter {
	const string name;
	const ulong increment;

	this(const string name, const ulong increment)
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.increment = increment;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		formattedWrite(buf, "%s%s:%s|m", prefix, this.name, this.increment);
	}
}

struct Set {
	const string name;
	const long value;

	this(const string name, const long value)
			@safe pure nothrow @nogc
	{
		this.name = name;
		this.value = value;
	}

	void toString(Buf)(Buf buf, const string prefix) const {
		formattedWrite(buf, "%s%s:%s|s", prefix, this.name, this.value);
	}
}

struct ScopeTimer {
	import core.time;

	string name;
	StatsD service;
	MonoTime begin;

	this(string name, StatsD service) {
		this.name = name;
		this.service = service;
		this.begin = MonoTime.currTime;
	}

	~this() {
		this.service(Timer(this.name, 
					(MonoTime.currTime - this.begin).total!"msecs"())
		);
	}

}

class StatsD {
	private string address;
	private ushort port;
	private string prefix;
	private UDPConnection connection;

	this(string address, ushort port, string prefix) {
		import std.array : back, empty;
		this.address = address;
		this.port = port;
		if(!prefix.empty && prefix.back != '.') {
			this.prefix = prefix ~ ".";
		} else {
			this.prefix = prefix;
		}
		this.connection = listenUDP(0);
		this.connection.connect(address, port);
	}

	void handleException(Exception e, const string f = __FILE__, 
			const int l = __LINE__) 
	{
		import std.stdio : writefln;
		writefln("%s:%s | %s", f, l, e.toString());
	}

	void opCall(Values...)(Values values) {
		static assert(values.length > 0);
		runTask({
			FixedSizeArray!(char,256 * values.length) buf;

			values[0].toString(buf[], this.prefix);

			foreach(ref it; values[1 .. $]) {
				buf.insertBack('\n');
				it.toString(buf[], this.prefix);
			}

			try {
				this.connection.send(cast(ubyte[])(buf));
			} catch(Exception e) {
				this.handleException(e);
			}
		});
	}

	void inc(const string name, const long value = 1, 
			const double sampleRate = double.nan) 
	{
		this.opCall(Counter(name, value, sampleRate));
	}

	void dec(const string name, const long value = -1, 
			const double sampleRate = double.nan) 
	{
		this.inc(name, value);
	}

	void set(const string name, const long value) {
		this.opCall(Set(name, value));
	}

	void meter(const string name, const ulong value) {
		this.opCall(Set(name, value));
	}

	void histo(const string name, const ulong value) {
		this.opCall(Histogram(name, value));
	}

	void time(const string name, const ulong time) {
		this.opCall(Timer(name, time));
	}

	void gauge(const string name, const ulong value) {
		this.opCall(Gauge(name, value));
	}

}

unittest {
	{
		FixedSizeArray!(char,128) textbuf;
		string h = "Hello World";
		formattedWrite(textbuf[], h);
		assert(cast(string)textbuf == h, cast(string)textbuf);
	}
	{
		FixedSizeArray!(char,128) textbuf;
		string h = "Hello World %s";
		string t = "Hello World 10";
		formattedWrite(textbuf[], h, 10);
		assert(cast(string)textbuf == t, cast(string)textbuf);
	}
}

unittest {
	import std.stdio;
	import core.time;
	runTask({
		auto udp_listener = listenUDP(1234);
		while(true) {
			auto pack = udp_listener.recv();
			writefln("Got packet: %s", cast(string)pack);
		}
	});

	auto s = new StatsD("127.0.0.1", 1234, "");
	foreach(it; 0 .. 5) {
		s(Counter("Foo", 2), Counter("Bar", -10), Timer("Time", 1337));
	}
	{
		auto a = ScopeTimer("args", s);
	}
	sleep(dur!"msecs"(100));
}
