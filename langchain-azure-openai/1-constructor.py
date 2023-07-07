from langchain.embeddings import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(
    
    
    model="text-embedding-ada-002",chunk_size = 1)
