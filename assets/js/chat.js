import {Socket, Presence} from "phoenix"

let Chat = {

  init() {
    if (!window.username) { return }
      // Socket
    let socket = new Socket("/socket", {
      params: {
        username: window.username, 
        room_id: window.room_id
      }
    })
    socket.connect()

    // Presence
    let presences = {}
    let globaPresences = {}

    let formatTimestamp = (timestamp) => {
      let date = new Date(timestamp)
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
      presences = Presence.syncState(presences, state)
      render(presences, userList)
    })

    room.on("presence_diff", diff => {
      presences = Presence.syncDiff(presences, diff)
      render(presences, userList)
    })

    room.join()

    globalAll.on("presence_state", state => {
      globaPresences = Presence.syncState(globaPresences, state)
      render(globaPresences, globalUserList)
    })

    globalAll.on("presence_diff", diff => {
      globaPresences = Presence.syncDiff(globaPresences, diff)
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
          room.push("message:new", messageInput.value)
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
          <b>${message.user}</b>
          <i>${formatTimestamp(message.timestamp)}</i>
          <p>${message.body}</p>
        `
        messageElement.addEventListener("click", (e) => {
          messageInput.value = "/" + message.user + " " + messageInput.value
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

export default Chat