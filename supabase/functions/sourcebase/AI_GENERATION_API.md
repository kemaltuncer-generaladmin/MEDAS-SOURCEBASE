# SourceBase AI Generation API Documentation

Bu doküman SourceBase AI içerik üretim sisteminin kullanımını açıklar.

## Genel Bakış

SourceBase, OpenAI ve gerektiğinde yapılandırılmış fallback sağlayıcılarıyla
çeşitli eğitim materyalleri üretir:
- **Flashcards**: Çalışma kartları
- **Quiz**: Çoktan seçmeli sorular
- **Summary**: Özet ve madde işaretli notlar
- **Algorithm**: Adım adım klinik algoritmalar
- **Comparison**: Karşılaştırma tabloları
- **Podcast**: Podcast scriptleri

## Mimari

```
Client -> Edge Function -> Job Processor -> AI Provider -> Database
```

### Async Job System

Tüm AI üretimi async job sistemi üzerinden çalışır:
1. Client job oluşturur (status: `queued`)
2. Job processor background'da işler (status: `processing`)
3. Router'ın seçtiği AI sağlayıcısından sonuç alınır
4. Job tamamlanır (status: `completed` veya `failed`)

## API Actions

### 1. process_file_extraction

Dosyadan metin çıkarımı yapar.

**Request:**
```json
{
  "action": "process_file_extraction",
  "payload": {
    "fileId": "uuid"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "fileId": "uuid",
    "textLength": 15000,
    "pageCount": 8,
    "chunkCount": 4,
    "tokenEstimate": 3750
  }
}
```

**Desteklenen Dosya Tipleri:**
- PDF
- DOCX
- PPTX

---

### 2. create_generation_job

AI içerik üretim işi başlatır.

**Request:**
```json
{
  "action": "create_generation_job",
  "payload": {
    "fileId": "uuid",  // optional
    "jobType": "flashcard",  // flashcard|quiz|summary|algorithm|comparison|podcast
    "sourceText": "Kaynak metin içeriği...",
    "count": 20,  // optional, flashcard ve quiz için
    "temperature": 0.7,  // optional, 0-1 arası
    "maxTokens": 2048  // optional
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "status": "queued",
    "jobType": "flashcard",
    "createdAt": "2026-05-16T00:00:00Z"
  }
}
```

**Job Types:**
- `flashcard`: Flashcard üretimi (count parametresi ile)
- `quiz`: Quiz soruları üretimi (count parametresi ile)
- `summary`: Özet üretimi
- `algorithm`: Algoritma üretimi
- `comparison`: Karşılaştırma tablosu
- `podcast`: Podcast scripti

---

### 3. get_job_status

İş durumunu sorgular.

**Request:**
```json
{
  "action": "get_job_status",
  "payload": {
    "jobId": "uuid"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "status": "completed",
    "jobType": "flashcard",
    "inputTokens": 3500,
    "outputTokens": 1200,
    "costEstimate": 0.00145,
    "errorMessage": null,
    "createdAt": "2026-05-16T00:00:00Z",
    "updatedAt": "2026-05-16T00:01:30Z"
  }
}
```

**Status Values:**
- `queued`: İş sırada bekliyor
- `processing`: İş işleniyor
- `completed`: İş tamamlandı
- `failed`: İş başarısız oldu
- `cancelled`: İş iptal edildi

---

### 4. get_generated_content

Tamamlanan işin içeriğini getirir.

**Request:**
```json
{
  "action": "get_generated_content",
  "payload": {
    "jobId": "uuid"
  }
}
```

**Response (Flashcard):**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "jobType": "flashcard",
    "content": [
      {
        "front": "Atriyal fibrilasyonun en sık nedeni nedir?",
        "back": "Hipertansiyon",
        "explanation": "HT, AF'nin en sık görülen risk faktörüdür.",
        "difficulty": "medium",
        "tags": ["kardiyoloji", "aritmi"]
      }
    ],
    "inputTokens": 3500,
    "outputTokens": 1200,
    "costEstimate": 0.00145
  }
}
```

**Response (Quiz):**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "jobType": "quiz",
    "content": [
      {
        "question": "Akut MI'da ilk 24 saatte hangi enzim yükselir?",
        "options": ["CK-MB", "Troponin", "Miyoglobin", "LDH"],
        "correctIndex": 2,
        "explanation": "Miyoglobin en erken yükselen kardiyak belirteçtir.",
        "difficulty": "hard"
      }
    ],
    "inputTokens": 3500,
    "outputTokens": 1500,
    "costEstimate": 0.00163
  }
}
```

**Response (Summary):**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "jobType": "summary",
    "content": {
      "bulletPoints": [
        "Kalp yetmezliği tanımı ve sınıflandırması",
        "Semptomlar: Dispne, ödem, yorgunluk",
        "Tedavi: ACE inhibitörleri, beta blokerler, diüretikler"
      ],
      "fullText": "Kalp yetmezliği, kalbin yeterli kan pompalayamadığı...",
      "keyTerms": ["Kalp yetmezliği", "EF", "NYHA"],
      "mainTopics": ["Tanı", "Tedavi", "Prognoz"]
    },
    "inputTokens": 4000,
    "outputTokens": 800,
    "costEstimate": 0.00140
  }
}
```

---

### 5. list_user_jobs

Kullanıcının tüm işlerini listeler.

**Request:**
```json
{
  "action": "list_user_jobs",
  "payload": {
    "limit": 50  // optional, default 50
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "jobs": [
      {
        "jobId": "uuid",
        "status": "completed",
        "jobType": "flashcard",
        "inputTokens": 3500,
        "outputTokens": 1200,
        "costEstimate": 0.00145,
        "errorMessage": null,
        "createdAt": "2026-05-16T00:00:00Z",
        "updatedAt": "2026-05-16T00:01:30Z"
      }
    ]
  }
}
```

---

### 6. cancel_job

İşi iptal eder.

**Request:**
```json
{
  "action": "cancel_job",
  "payload": {
    "jobId": "uuid"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "jobId": "uuid",
    "status": "cancelled"
  }
}
```

---

### 7. retry_job

Başarısız işi yeniden dener.

**Request:**
```json
{
  "action": "retry_job",
  "payload": {
    "jobId": "uuid"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "oldJobId": "uuid",
    "newJobId": "uuid",
    "status": "queued"
  }
}
```

---

## Kullanım Örnekleri

### Örnek 1: Dosyadan Flashcard Üretimi

```typescript
// 1. Dosyayı yükle (mevcut upload flow)
const uploadResult = await createUploadSession({...});
await uploadFile(uploadResult.uploadUrl, file);
await completeUpload({...});

// 2. Dosyadan metin çıkar
const extraction = await fetch(edgeFunction, {
  method: 'POST',
  headers: {
    'authorization': `Bearer ${token}`,
    'content-type': 'application/json'
  },
  body: JSON.stringify({
    action: 'process_file_extraction',
    payload: { fileId: uploadResult.fileId }
  })
});

// 3. Flashcard üretim işi başlat
const jobResponse = await fetch(edgeFunction, {
  method: 'POST',
  headers: {
    'authorization': `Bearer ${token}`,
    'content-type': 'application/json'
  },
  body: JSON.stringify({
    action: 'create_generation_job',
    payload: {
      fileId: uploadResult.fileId,
      jobType: 'flashcard',
      sourceText: extractedText,
      count: 30
    }
  })
});

const { jobId } = jobResponse.data;

// 4. Job durumunu poll et
const pollStatus = async () => {
  const status = await fetch(edgeFunction, {
    method: 'POST',
    headers: {
      'authorization': `Bearer ${token}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      action: 'get_job_status',
      payload: { jobId }
    })
  });
  
  if (status.data.status === 'completed') {
    // 5. İçeriği al
    const content = await fetch(edgeFunction, {
      method: 'POST',
      headers: {
        'authorization': `Bearer ${token}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify({
        action: 'get_generated_content',
        payload: { jobId }
      })
    });
    
    return content.data.content;
  } else if (status.data.status === 'failed') {
    throw new Error(status.data.errorMessage);
  }
  
  // Henüz tamamlanmadı, tekrar dene
  await new Promise(resolve => setTimeout(resolve, 2000));
  return pollStatus();
};

const flashcards = await pollStatus();
```

---

## Limitler ve Kısıtlamalar

### Token Limitleri
- **Max Input**: 8,000 tokens (~32,000 karakter)
- **Max Output**: 2,048 tokens (configurable)
- Uzun metinler otomatik olarak chunk'lara bölünür

### Rate Limiting
- Kullanıcı başına eşzamanlı 5 job
- Dakikada max 20 job başlatma

### Dosya Limitleri
- **Max File Size**: 100 MB
- **Supported Types**: PDF, DOCX, PPTX

### Cost Estimation
Router model ve kalite seviyesine göre provider maliyeti tahmin edilir.

Örnek maliyet:
- 20 flashcard (~3500 input, ~1200 output): ~$0.0015
- 30 quiz soru (~4000 input, ~1500 output): ~$0.0018
- 1 özet (~4000 input, ~800 output): ~$0.0014

---

## Hata Kodları

| Kod | Açıklama |
|-----|----------|
| `CONFIG_ERROR` | Sunucu yapılandırması eksik |
| `FILE_NOT_FOUND` | Dosya bulunamadı |
| `UNSUPPORTED_FILE_TYPE` | Dosya tipi desteklenmiyor |
| `TEXT_TOO_LONG` | Kaynak metin çok uzun |
| `UNSUPPORTED_JOB_TYPE` | İş tipi desteklenmiyor |
| `JOB_NOT_FOUND` | İş kaydı bulunamadı |
| `JOB_NOT_COMPLETED` | İş henüz tamamlanmadı |
| `JOB_ALREADY_FINISHED` | İş zaten tamamlanmış |
| `JOB_NOT_FAILED` | Sadece başarısız işler retry edilebilir |
| `INVALID_CONTENT` | AI çıktısı validation'dan geçemedi |
| `OPENAI_AUTH_FAILED` | OpenAI kimlik doğrulama başarısız |
| `ANTHROPIC_AUTH_FAILED` | Anthropic kimlik doğrulama başarısız |
| `IMAGE_AUTH_FAILED` | Görsel sağlayıcı kimlik doğrulama başarısız |
| `AI_FAILED` | AI içerik üretimi başarısız |

---

## Güvenlik

### AGENTS.md Kurallarına Uyum

1. **API Key Güvenliği**: AI provider key'leri sadece server-side
2. **Prompt Injection Prevention**: Kaynak metni data olarak işlenir
3. **Token Limitleri**: Max 8K input kontrolü
4. **Cost Tracking**: Her job için maliyet kaydedilir
5. **Error Handling**: Güvenli hata mesajları
6. **Audit Logging**: Tüm işlemler loglanır

### RLS Policies

- Kullanıcı sadece kendi joblarını görebilir
- Job içeriği sadece job sahibine döndürülür
- Service role key sadece Edge Function'da kullanılır

---

## Environment Variables

```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxx

# AI Providers
OPENAI_API_KEY=xxx
ANTHROPIC_API_KEY=xxx # optional text fallback
STABILITY_API_KEY=xxx # optional image fallback

# Object Storage (for file storage)
STORAGE_DRIVER=s3
S3_ENDPOINT=https://nbg1.your-objectstorage.com
S3_REGION=nbg1
S3_BUCKET=medasistorage
S3_ACCESS_KEY=xxx
S3_SECRET_KEY=xxx
```

---

## Monitoring

### Job Metrics

```sql
-- Başarı oranı
SELECT 
  job_type,
  COUNT(*) as total,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
FROM sourcebase.generated_jobs
GROUP BY job_type;

-- Ortalama işlem süresi
SELECT 
  job_type,
  AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_duration_seconds
FROM sourcebase.generated_jobs
WHERE status = 'completed'
GROUP BY job_type;

-- Toplam maliyet
SELECT 
  SUM(cost_estimate) as total_cost,
  SUM(input_tokens) as total_input_tokens,
  SUM(output_tokens) as total_output_tokens
FROM sourcebase.generated_jobs
WHERE status = 'completed';
```

---

## Gelecek Geliştirmeler

- [ ] Batch processing (birden fazla dosya)
- [ ] Custom prompt templates
- [ ] Multi-language support
- [ ] Image extraction from PDFs
- [ ] Audio transcript generation
- [ ] Real-time streaming responses
- [ ] Webhook notifications
- [ ] Job priority queue

---

## Destek

Sorularınız için: [GitHub Issues](https://github.com/kemaltuncer-generaladmin/medasi-sourcebase/issues)
