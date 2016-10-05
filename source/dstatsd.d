import dstatsd;

import vibe.core.core;
import vibe.core.net;

class StatsD {
	private string address;
	private ushort port;
	private string prefix;
	private UDPConnection connection;

	this(string address, ushort port, string prefix) {
		this.address = address;
		this.port = port;
		this.prefix = prefix;
		this.connection = listenUDP(this.port, this.address);
	}

	void inc(const string name, const long value = 1) {
		this.impl(name, value, "c", 1.0);
	}

	private void impl(const string name, const long value, const string kind, 
			const double ratio) 
	{
		import std.algorithm.mutation : copy;
		import std.format : formattedWrite;
		import std.internal.scopebuffer;
		import std.stdio : writefln;
		//runTask({
			char[256] buf = void;
			auto textbuf = ScopeBuffer!char(buf);
			const len = formattedWrite(textbuf, "%s:%s|%s", name, value, kind);
			writefln("%s %s %s %s %s", len, name, value, kind, buf[0 .. len]);
			connection.send(cast(ubyte[])buf[0 .. len]);
		//});
	}
}

unittest {
	import std.stdio : writefln;
	runTask({
		while(true) {
		auto udp_listener = listenUDP(1234);
		auto pack = udp_listener.recv();
		writefln("Got packet: %s", cast(string)pack);
		}
	});

	auto s = new StatsD("127.0.0.1", 1234, "");
	s.inc("Foo");
}
