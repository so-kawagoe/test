import { useEffect, useState } from "react";
import "./App.css";
import Main from "./components/Main";
import Sidebar from "./components/Sidebar";
import axios from "axios";

const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:3001";

function App() {
  const [notes, setNotes] = useState([]);
  const [activeNote, setActiveNote] = useState(null);

  useEffect(() => {
    const fetchNotes = async () => {
      try {
        const response = await axios.get(`${API_BASE_URL}/notes`);
        setNotes(response.data);
        // 初回ロード時のみ最初のメモを選択
        if (response.data.length > 0 && !activeNote) {
          setActiveNote(response.data[0].id);
        }
      } catch (error) {
        console.error("メモ取得エラー:", error.response?.data || error.message);
      }
    };
    fetchNotes();
  }, []);

  const onAddNote = async () => {
    try {
      const response = await axios.post(`${API_BASE_URL}/notes`, {
        title: "",
        content: "",
        modDate: new Date().toISOString(),
      });

      const newNote = response.data;
      setNotes((prevNotes) => [...prevNotes, newNote]);
      setActiveNote(newNote.id);

      console.log("新規メモを作成:", newNote);
    } catch (error) {
      console.error("メモ作成エラー:", error.response?.data || error.message);
    }
  };

  const onDeleteNote = async (id) => {
    await axios.delete(`${API_BASE_URL}/notes/${id}`);
    const filterNotes = notes.filter((note) => note.id !== id);
    setNotes(filterNotes);
  };

  const getActiveNote = () => {
    return notes.find((note) => note.id === activeNote);
  };

  const onUpdateNote = async (updatedNote) => {
    try {
      if (!updatedNote || !updatedNote.id) {
        console.error("無効なメモデータ:", updatedNote);
        return;
      }

      const response = await axios.put(
        `${API_BASE_URL}/notes/${updatedNote.id}`,
        {
          title: updatedNote.title || "無題",
          content: updatedNote.content || "",
          modDate: new Date().toISOString(),
        }
      );

      console.log("更新レスポンス:", response.data);

      setNotes((prevNotes) =>
        prevNotes.map((note) =>
          note.id === updatedNote.id ? response.data : note
        )
      );
    } catch (error) {
      console.error("更新エラー:", error);
    }
  };

  return (
    <div className="App">
      <Sidebar
        onAddNote={onAddNote}
        notes={notes}
        onDeleteNote={onDeleteNote}
        activeNote={activeNote}
        setActiveNote={setActiveNote}
      />
      <Main activeNote={getActiveNote()} onUpdateNote={onUpdateNote} />
    </div>
  );
}

export default App;
