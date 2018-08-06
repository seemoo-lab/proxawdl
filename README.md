# proxAWDL

Tunnels a regular TCP connection (e.g., `iperf`) through an AWDL link by exploiting the [NetService](https://developer.apple.com/documentation/foundation/netservice) API. ~~Workaround because Apple prevents regular sockets from listening or connecting to `awdl0`.~~ As an alternative, there is a special XNU socket option [`SO_RECV_ANYIF`](https://opensource.apple.com/source/xnu/xnu-4570.41.2/bsd/sys/socket.h) to allow sending/receiving via AWDL:

```c
#define SO_RECV_ANYIF 0x1104 /* unrestricted inbound processing */
```

## Usage

Frist compile with Xcode.

Then, on the **server**, run
```
./proxawdl
```
and start the TCP server listening on `localhost`, e.g., `iperf -s -p 22222`.

On the **client**, run
```
./proxawdl client
```
and start the TCP client connecting to `localhost`, e.g., `iperf -c -p 22222`.

## Limitations

* hardcoded TCP ports

* does not multiplex TCP connections which means that applications using multiple TCP connections will probably not function properly

## Contact

* **Milan Stute** ([email](mailto:mstute@seemoo.tu-darmstadt.de), [web](https://seemoo.de/mstute))

## Credits

* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) to handle local TCP connections (as static dependency)
