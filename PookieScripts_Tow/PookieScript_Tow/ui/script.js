// Ensure the UI is hidden by default
document.getElementById("playerList").style.display = "none";

window.addEventListener("message", (event) => {
    const data = event.data;

    if (data.type === "show") {
        console.log("Received 'show' event. Displaying UI.");
        document.getElementById("playerList").style.display = "block";
    }

    if (data.type === "hide") {
        console.log("Received 'hide' event. Hiding UI.");
        document.getElementById("playerList").style.display = "none";
    }

    if (data.type === "updatePlayerList") {
        console.log("Received 'updatePlayerList' event. Updating player list.");
        const body = document.getElementById("playerListBody");
        body.innerHTML = "";

        Object.values(data.players).forEach(player => {
            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${player.name}</td>
                <td>${player.id}</td>
                <td>N/A</td> <!-- Placeholder for Discord name -->
            `;

            body.appendChild(row);
        });

        document.getElementById("playerCount").textContent = `Players: ${Object.keys(data.players).length} / 64`;
    }

    // Mechanic menu NUI logic
    if (data.type === "showMechanicMenu") {
        document.getElementById("mechanicMenu").style.display = "block";
    }
    if (data.type === "hideMechanicMenu") {
        document.getElementById("mechanicMenu").style.display = "none";
    }
});

// Close the UI when the "Close" button is clicked
document.getElementById("closeButton").addEventListener("click", () => {
    console.log("Close button clicked. Sending 'close' request to server.");
    fetch(`https://${GetParentResourceName()}/close`, { method: "POST" });
});

// Mechanic menu button handlers
document.querySelectorAll(".mc-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        const action = btn.getAttribute("data-action");
        if (action) {
            fetch(`https://${GetParentResourceName()}/mechanicAction`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action })
            });
        }
    });
});

// Close mechanic menu
document.getElementById("closeMechanicMenu").addEventListener("click", () => {
    fetch(`https://${GetParentResourceName()}/closeMechanicMenu`, { method: "POST" });
});
