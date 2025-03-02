const express = require("express");
const { Pool } = require("pg");
const cors = require("cors");
require("dotenv").config();

const app = express();

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

app.use(cors());
app.use(express.json());

app.get("/notes", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, title, content, modDate::timestamp with time zone as modDate FROM notes ORDER BY modDate DESC"
    );

    const notesWithFormattedDates = result.rows.map((note) => {
      try {
        return {
          id: note.id,
          title: note.title,
          content: note.content,
          modDate: note.moddate
            ? new Date(note.moddate).toISOString()
            : new Date().toISOString(),
        };
      } catch (error) {
        console.error(`日付処理エラー:`, {
          noteId: note.id,
          modDate: note.moddate,
          error: error.message,
        });
        return {
          id: note.id,
          title: note.title,
          content: note.content,
          modDate: new Date().toISOString(),
        };
      }
    });

    console.log("取得したメモ:", notesWithFormattedDates);
    res.json(notesWithFormattedDates);
  } catch (err) {
    console.error("データ取得エラー:", err);
    res.status(500).json({ error: err.message });
  }
});

app.post("/notes", async (req, res) => {
  try {
    const { title, content } = req.body;
    console.log("受信したデータ:", { title, content });

    const now = new Date();

    const result = await pool.query(
      "INSERT INTO notes (title, content, modDate) VALUES ($1, $2, $3) RETURNING *",
      [title || "", content || "", now]
    );

    const newNote = {
      id: result.rows[0].id,
      title: result.rows[0].title,
      content: result.rows[0].content,
      modDate: now.toISOString(),
    };

    console.log("保存されたメモ:", newNote);
    res.json(newNote);
  } catch (err) {
    console.error("エラー詳細:", err);
    res.status(500).json({ error: err.message });
  }
});

app.delete("/notes/:id", async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query("DELETE FROM notes WHERE id = $1", [id]);
    res.json({ message: "Note deleted" });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ error: err.message });
  }
});

app.put("/notes/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content } = req.body;

    const result = await pool.query(
      `UPDATE notes 
       SET title = $1, 
           content = $2, 
           modDate = CURRENT_TIMESTAMP 
       WHERE id = $3 
       RETURNING id, title, content, modDate`,
      [title, content, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "メモが見つかりません" });
    }

    const updatedNote = {
      id: result.rows[0].id,
      title: result.rows[0].title,
      content: result.rows[0].content,
      modDate: result.rows[0].moddate.toISOString(),
    };

    console.log("更新されたメモ:", updatedNote);
    res.json(updatedNote);
  } catch (err) {
    console.error("エラー詳細:", err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
