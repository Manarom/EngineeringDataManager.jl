from collections import namedtuple
import json
import socket
import time
JSN = namedtuple('JSN','property,material,format')



def get_property_from_base(property_name, material_name, data_type,port = 2000):
    out_line = ""
    try:
        json_str =  json.dumps(JSN(property_name, material_name, data_type)._asdict())
        clientsocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        clientsocket.connect(('localhost', port))
        file_like_sock = clientsocket.makefile('rw')
        file_like_sock.write('request_property_data\n')
        file_like_sock.flush()
        # clientsocket.sendall(bytes("request_property_data\n\r",encoding="utf-8"))
        #time.sleep(2)
        file_like_sock.write(json_str + "\n")
        file_like_sock.flush()
        #time.sleep(2)
        buffer = b""
        # clientsocket.settimeout(20)
        while not (buffer.endswith(b"\n") or  buffer.endswith(b"\r")):
            data = clientsocket.recv(1024)
            if not data:
                break
            buffer += data
            out_line = buffer.decode("utf-8").strip()
    except socket.timeout:
        print("Timeout: No data received within 10 seconds")
    finally:
        clientsocket.close()
        return out_line
#