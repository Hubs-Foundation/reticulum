import {Socket, Presence} from "phoenix"

let ChatClient = {

  init() {
    if (!window.username) { return }

    let encode = function(msg, callback) {
      let builder = new flatbuffers.Builder(1024)

      let body, sender, receiver, timestamp, join_ref

      if(msg.payload.body)
        body = builder.createString(msg.payload.body)
      if(msg.payload.sender)
        sender = builder.createString(msg.payload.sender)
      if(msg.payload.receiver)
        receiver = builder.createString(msg.payload.receiver)
      if(msg.payload.timestamp)
        timestamp = builder.createString(msg.payload.timestamp)

      Chat.Payload.startPayload(builder)
      if(body)
        Chat.Payload.addBody(builder, body)
      if(sender)
        Chat.Payload.addSender(builder, sender)
      if(receiver)
        Chat.Payload.addReceiver(builder, receiver)
      if(timestamp)
        Chat.Payload.addTimestamp(builder, timestamp)

      let payload = Chat.Payload.endPayload(builder)
      if(msg.join_ref)
        join_ref = builder.createString(msg.join_ref)
      let ref = builder.createString(msg.ref)
      let topic = builder.createString(msg.topic)
      let event = builder.createString(msg.event)
      let status
      if (msg.status)
        status = msg.status

      Chat.Message.startMessage(builder)
      if(join_ref)
        Chat.Message.addJoinRef(builder, join_ref)
      Chat.Message.addRef(builder, ref)
      Chat.Message.addTopic(builder, topic)
      Chat.Message.addEvent(builder, event)
      if(status)
        Chat.Message.addStatus(builder, status)
      Chat.Message.addPayload(builder, payload)
      let message = Chat.Message.endMessage(builder)
      Chat.Message.finishMessageBuffer(builder, message)
      let buf = builder.asUint8Array()

      return callback(buf)
    }

    let decode = function(rawPayload, callback) {
      let bytes = new Uint8Array(rawPayload)
      let buf = new flatbuffers.ByteBuffer(bytes)

      let msgBuf = Chat.Message.getRootAsMessage(buf)
      let payload = msgBuf.payload()

      let resp = {
        join_ref: msgBuf.joinRef(),
        ref: msgBuf.ref(), 
        topic: msgBuf.topic(), 
        event: msgBuf.event(),
        status: msgBuf.status(),
        payload: {
          body: payload.body(),
          sender: payload.sender(),
          receiver: payload.receiver(),
          timestamp: payload.timestamp(),
          status: payload.status(),
          response: {}, //todo
          joins: {},
          leaves: {},
          state: {}
        }
      }

      parse_presence(resp, payload, "joins")
      parse_presence(resp, payload, "leaves")
      parse_presence(resp, payload, "state")

      return callback(resp)
    }

    let parse_presence = function(resp, payload, name) {
        for (let i = 0; i < payload[name + "Length"](); i++) {
        let payloadRoot = payload[name](i)
        let respRoot = resp.payload[name]
        let user = payloadRoot.user()
        respRoot[user] = {metas: []}
        for (let j = 0; j < payloadRoot.metasLength(); j++) {
          respRoot[user].metas[j] = {
            online_at: payloadRoot.metas(j).onlineAt(),
            phx_ref: payloadRoot.metas(j).phxRef()
          }
        }
      }
    }

      // Socket
    let socket = new Socket("/socket", {
      params: {
        username: window.username, 
        room_id: window.room_id
      },
      encode: encode, //flatbuffers
      decode: decode //flatbuffers
    })

    socket.connect()

    socket.conn.binaryType = 'arraybuffer' //flatbuffers

    // Presence
    let presences = {}
    let globaPresences = {}

    let formatTimestamp = (timestamp) => {
      let date = new Date(timestamp * 1000)
      return date.toLocaleTimeString()
    }

    let listBy = (user, {metas: metas}) => {
      return {
        user: user,
        onlineAt: formatTimestamp(metas[0].online_at)
      }
    }

    let userList = document.getElementById("UserList")
    let globalUserList = document.getElementById("GlobalUserList")

    let render = (presences, list) => {
      list['innerHTML'] = Presence.list(presences, listBy)
        .map(presence => `
          <li id="${list.id + ":" + presence.user}">
            <b>${presence.user}</b>
            <br><small>online since ${presence.onlineAt}</small>
          </li>
        `)
        .join("")

      Presence.list(presences, listBy).forEach(presence => {
        document.getElementById(list.id + ":" + presence.user).addEventListener("click", (e) => {
          messageInput.value = "/" + presence.user + " " + messageInput.value
          messageInput.focus()
        })
      })
    }

    // Channels
    let room = socket.channel("room:" + window.room_id)
    let globalAll = socket.channel("global:all")
    let globalUser = socket.channel("global:" + window.username)
    let globalUsers = {}

    globalUser.join()

    room.on("presence_state", state => {
      presences = Presence.syncState(presences, state.state)
      render(presences, userList)
    })

    room.on("presence_diff", diff => {
      presences = Presence.syncDiff(presences, {joins: diff.joins, leaves: diff.leaves})
      render(presences, userList)
    })

    room.join()

    globalAll.on("presence_state", state => {
      globaPresences = Presence.syncState(globaPresences, state.state)
      render(globaPresences, globalUserList)
    })

    globalAll.on("presence_diff", diff => {
      globaPresences = Presence.syncDiff(globaPresences, {joins: diff.joins, leaves: diff.leaves})
      render(globaPresences, globalUserList)
    })

    globalAll.join()

    //Messages
    let messageInput = document.getElementById("NewMessage")

    messageInput.addEventListener("keypress", (e) => {
      if (e.keyCode == 13 && messageInput.value != "") {

        if(messageInput.value.charAt(0) == '/') {
          let emailString = messageInput.value.split(' ')[0].substring(1);
          
          if(!globalUsers[emailString]) {
            let topic = "global:" + emailString
            globalUsers[emailString] = socket.channel(topic)
            globalUsers[emailString].join()
            globalUsers[emailString].on("message:new", message => renderMessage(message, false))
          }

          let date = new Date()
          let message = {
            body: messageInput.value.substring(emailString.length + 1),
            receiver: emailString,
            sender: window.username,
            timestamp: date
          }
          renderMessage(message, true, true)
          globalUsers[emailString].push("message:new", message)

        } else {
          let message = {
            body: messageInput.value,
            sender: window.username,
          }
          room.push("message:new", message)
        }
        messageInput.value = ""
      }
    })

    let messageList = document.getElementById("MessageList")

    let renderMessage = (message, isDirect = false, isSender = false) => {
      let messageElement = document.createElement("li")
      if (isDirect) {
        messageElement.innerHTML = `
          <b>(DM) ${isSender ? "to: " + message.receiver : "from: " + message.sender}</b>
          <i>${formatTimestamp(message.timestamp)}</i>
          <p>${message.body}</p>
        `
        messageElement.addEventListener("click", (e) => {
          messageInput.value = "/" + (isSender ? message.receiver : message.sender) + " " + messageInput.value
          messageInput.focus()
        })
      } else {
        messageElement.innerHTML = `
          <b>${message.sender}</b>
          <i>${formatTimestamp(message.timestamp)}</i>
          <p>${message.body}</p>
        `
        messageElement.addEventListener("click", (e) => {
          messageInput.value = "/" + message.sender + " " + messageInput.value
          messageInput.focus()
        })
      }

      messageList.appendChild(messageElement)
      messageList.scrollTop = messageList.scrollHeight;
    }

    room.on("message:new", message => renderMessage(message))

    globalUser.on("message:new", message => renderMessage(message, true))
  }
}

export default ChatClient