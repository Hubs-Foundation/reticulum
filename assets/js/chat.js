import {Socket, Presence} from "phoenix"

let Chat = {

  init() {
    if (!window.username) { return }
      // Socket
    let socket = new Socket("/socket", {params: {username: window.username}})
    socket.connect()

    // Presence
    let presences = {}

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
    let render = (presences) => {
      userList.innerHTML = Presence.list(presences, listBy)
        .map(presence => `
          <li>
            <b>${presence.user}</b>
            <br><small>online since ${presence.onlineAt}</small>
          </li>
        `)
        .join("")
    }

    // Channels
    let room = socket.channel("room:lobby")

    room.on("presence_state", state => {
      presences = Presence.syncState(presences, state)
      render(presences)
    })

    room.on("presence_diff", diff => {
      presences = Presence.syncDiff(presences, diff)
      render(presences)
    })

    room.join()

    //Messages
    let messageInput = document.getElementById("NewMessage")

    messageInput.addEventListener("keypress", (e) => {
      if (e.keyCode == 13 && messageInput.value != "") {
        room.push("message:new", messageInput.value)
        messageInput.value = ""
      }
    })

    let messageList = document.getElementById("MessageList")

    let renderMessage = (message) => {
      let messageElement = document.createElement("li")
      messageElement.innerHTML = `
        <b>${message.user}</b>
        <i>${formatTimestamp(message.timestamp)}</i>
        <p>${message.body}</p>
      `
      messageList.appendChild(messageElement)
      messageList.scrollTop = messageList.scrollHeight;
    }

    room.on("message:new", message => renderMessage(message))
  }
}

export default Chat