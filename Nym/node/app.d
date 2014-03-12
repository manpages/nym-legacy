import std.stdio;
import std.string;
import std.conv;
import std.typecons;
import deimos.zmq.zmq;
import Nym.core.data;
//import Nym.persist.lib;
alias state = string[][string][string];
alias response = Tuple!(string, state);

void main() {
  writeln("Starting nym node");
  void* context = zmq_init(1);

  void* socket = zmq_socket(context, ZMQ_REP);
  zmq_bind(socket, toStringz(`tcp://*:67831`));

  while (true) {
    writeln("Initializing zmq message");
    zmq_msg_t req;
    zmq_msg_init(&req);
    writeln("Done.");
    writeln("Getting request");
    long bytes = zmq_recvmsg(socket, &req, 0);
    if(bytes == -1) {
      import core.stdc.errno; 
      writeln(to!string(cast(char*)zmq_strerror(errno)));
      return;
    }
    immutable string data = to!string((cast(char*)zmq_msg_data(&req))[0 .. bytes]);
    zmq_msg_close(&req);
    writeln("Done.");

    // todo: add fibers
    // infiber worker
    auto result = handle(data);
    writeln("Got result! Status is " ~ result[0]);
    foreach(k, v; result[1]) {
      writeln(k);
      foreach(kk, vv; v) {
        writeln("  " ~ kk);
        foreach(vvv; vv) {
          writeln("    " ~ vvv);
        }
      }
    }
    zmq_msg_t reply;
    zmq_msg_init_size(&reply, data.length);
    (zmq_msg_data(&reply))[0 .. data.length] = (cast(immutable(void*))data.ptr)[0 .. data.length];
    zmq_sendmsg(socket, &reply, 0);
    zmq_msg_close(&reply);
    // outfiber worker
    // infiber response server
    
    // outfiber response server
  }

  //zmq_close(socket);
  //zmq_term(context);
}

response handle(immutable string request) {
  import std.array;
  import Nym.core.lib;
  string[] rpc_args = split(request);
  mixin(gencode_dispatch([ "add", "alias", "info" ]));
  return dispatch(rpc_args);
}

immutable string gencode_dispatch(immutable string[] verbs) @safe pure {  
  string code = `response dispatch(string[] x) {` ~
                `  response result;` ~
                `  switch(x[0]) {`;
  foreach(verb; verbs) {
    code ~=     `    case "` ~ verb ~ `": ` ~ 
                `      result = rpc_` ~ verb ~ `(x[1 .. $]);` ~
                `      break;`;
  }
  code ~=       `    default: result = rpc_default(x); }` ~
                `  return result; }`;
  return code;
}
