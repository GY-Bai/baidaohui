from supabase_presta import app
import os

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5004))
    app.run(debug=True, host='0.0.0.0', port=port) 