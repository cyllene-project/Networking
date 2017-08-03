import Libc
import Foundation

// to avoid ambiguity between the Socket methods and the libc/darwin system calls.
private var cclose = close
private var clisten = listen
private var cshutdown = shutdown

// MARK: - Socket

class Socket {
  private static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try Error.makeAndThrow(fromReturnCode: ret)
    return v
  }

  private static func setOption(fd: Int32, option: Int32, value: Int32) throws {
    var v = value
    let ret = setsockopt(fd, SOL_SOCKET, option, &v, socklen_t(MemoryLayout<Int32>.size))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func setTimevalOption(fd: Int32, option: Int32, t: TimeInterval) throws {
    var val = timeval()

    // see https://stackoverflow.com/a/28872601/1094941
    if t > 0 {
      val.tv_sec = Int(t)

      let us = Int(t.truncatingRemainder(dividingBy: 1) * 1_000_000)
      #if os(Linux)
				val.tv_usec = Int(us)
			#else
				val.tv_usec = Int32(us)
			#endif
    }

		let ret = setsockopt(fd, SOL_SOCKET, option, &val, socklen_t(MemoryLayout<timeval>.stride))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func setLingerOption(fd: Int32, on: Bool, t: TimeInterval) throws {
    var val = linger()

    val.l_onoff = on ? 1 : 0
    val.l_linger = 0
    if on && t > 0 {
      let secs = Int32(t)
      val.l_linger = secs
    }

    #if os(Linux)
      let option = SO_LINGER
    #else
      let option = SO_LINGER_SEC
    #endif

		let ret = setsockopt(fd, SOL_SOCKET, option, &val, socklen_t(MemoryLayout<linger>.stride))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func setFcntl(fd: Int32, flag: Int32) throws {
    let flags = fcntl(fd, F_GETFL)
    try Error.makeAndThrow(fromReturnCode: flags)

    // if flag is negative, unset the flag
    let new = flag >= 0 ? (flags | flag) : (flags & ~(-flag))

    let ret = fcntl(fd, F_SETFL, new)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  // MARK: - ShutdownMode

  struct ShutdownMode {
    let value: Int32

    private init(value: Int32) {
      self.value = value
    }

    static let read = ShutdownMode(value: SHUT_RD)
    static let write = ShutdownMode(value: SHUT_WR)
    static let readWrite = ShutdownMode(value: SHUT_RDWR)
  }

  // MARK: - Properties

  let fd: Int32
  let family: Family
  let type: SocketType
  let proto: SocketProtocol

  // MARK: - Constructors

  init(family: Family = .ip4, type: SocketType = .stream, proto: SocketProtocol = .tcp) throws {
    let fd = socket(family.value, type.value, proto.value)
    try Error.makeAndThrow(fromReturnCode: fd)

    self.fd = fd
    self.family = family
    self.type = type
    self.proto = proto
  }

  init(fd: Int32) throws {
    self.fd = fd

    #if os(Linux)
      self.family = Family.make(try Socket.getOption(fd: fd, option: SO_DOMAIN))
      self.proto = SocketProtocol.make(try Socket.getOption(fd: fd, option: SO_PROTOCOL))
    #else
      self.family = .unknown
      self.proto = .unknown
    #endif

    self.type = SocketType.make(try Socket.getOption(fd: fd, option: SO_TYPE))
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func setOption(_ option: Int32, to value: Int) throws {
    try Socket.setOption(fd: fd, option: option, value: Int32(value))
  }

  func getOption(_ option: Int32) throws -> Int {
    return Int(try Socket.getOption(fd: fd, option: option))
  }

  func setReadTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fd, option: SO_RCVTIMEO, t: t)
  }

  func getReadTimeout() throws -> TimeInterval {

  }

  func setWriteTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fd, option: SO_SNDTIMEO, t: t)
  }

  func getWriteTimeout() throws -> TimeInterval {

  }

  func setLinger(timeout: TimeInterval) throws {
    try Socket.setLingerOption(fd: fd, on: true, t: timeout)
  }

  func setNoLinger() throws {
    try Socket.setLingerOption(fd: fd, on: false, t: 0)
  }

  func getLinger() throws -> TimeInterval? {

  }

  func setBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: -O_NONBLOCK)
  }

  func setNonBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: O_NONBLOCK)
  }

  func isBlocking() throws -> Bool {

  }

  func listen(backlog: Int) throws {
    let ret = clisten(fd, Int32(backlog))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  func shutdown(mode: ShutdownMode = .readWrite) throws {
    let ret = cshutdown(fd, mode.value)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  func close() throws {
    let ret = cclose(fd)
    try Error.makeAndThrow(fromReturnCode: ret)
  }
}
