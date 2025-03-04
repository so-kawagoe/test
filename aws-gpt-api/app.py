from flask import Flask, request, jsonify
from openai import OpenAI
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

client = OpenAI(
    api_key=os.getenv('OPENAI_API_KEY')
)

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        message = data.get('message',"")

        if not message:
            return jsonify({'error': 'No message provided'}), 400

        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "user", "content": message}
            ]
        )

        response_text = response.choices[0].message.content

        return jsonify({'response': response_text})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)