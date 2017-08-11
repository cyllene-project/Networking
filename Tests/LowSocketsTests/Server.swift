import Libc
import LowSockets

class UnixServer {
  let path: String
  private var sock: Socket? = nil

  init(_ path: String) {
    self.path = path
  }

  deinit {
    unlink(path)
  }

  func listen() throws {
    let sock = try Socket(family: .unix)
    self.sock = sock

    try sock.bind(to: path)
    try sock.listen()
  }

  func serve(_ handler: (Socket) throws -> Bool) throws {
    guard let sock = sock else {
      throw MessageError("no listening socket")
    }
    while true {
      let remote = try sock.accept()
      defer { try? remote.close() }

      if !(try handler(remote)) {
        try sock.close()
        return
      }
    }
  }
}