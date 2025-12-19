# Databricks AI Assistant Architecture Guide

This guide documents the complete AI assistant implementation pattern for Databricks Apps, including LLM integration, async processing, Genie SQL integration, and UI components.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND (React)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │ AI Notification  │  │ Floating AI      │  │ Domain-Specific          │   │
│  │ Badge            │  │ Assistant        │  │ AI Component (e.g. ARIA) │   │
│  │ (Header)         │  │ (Chat Widget)    │  │                          │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────────┬─────────────┘   │
│           │                     │                         │                  │
│           └─────────────────────┼─────────────────────────┘                  │
│                                 ▼                                            │
│                    ┌──────────────────────────┐                              │
│                    │   AsyncAIContext         │                              │
│                    │   (React Context)        │                              │
│                    │   - Polling (2s/30s)     │                              │
│                    │   - Request caching      │                              │
│                    │   - Status management    │                              │
│                    └────────────┬─────────────┘                              │
└─────────────────────────────────┼────────────────────────────────────────────┘
                                  │ HTTP
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND (FastAPI)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     Async AI Router (/api/ai/async/*)                 │   │
│  │  POST /submit  │  GET /pending  │  GET /status/{id}  │  GET /result  │   │
│  └───────────────────────────────────┬──────────────────────────────────┘   │
│                                      │                                       │
│                                      ▼                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Background Task Processor                          │  │
│  │                    (FastAPI BackgroundTasks)                          │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                       │
│         ┌────────────────────────────┼────────────────────────────┐         │
│         ▼                            ▼                            ▼         │
│  ┌─────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐   │
│  │   LLM Service   │   │   Genie SQL Service  │   │ Multi-Agent Service │   │
│  │   (Llama 4)     │   │   (Natural Language) │   │      (MAS)          │   │
│  └────────┬────────┘   └──────────┬───────────┘   └──────────┬──────────┘   │
│           │                       │                          │              │
└───────────┼───────────────────────┼──────────────────────────┼──────────────┘
            │                       │                          │
            ▼                       ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATABRICKS PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐   │
│  │ Model Serving   │   │    Genie Spaces      │   │   Agent Endpoints   │   │
│  │ Endpoints       │   │    + SQL Warehouse   │   │                     │   │
│  └─────────────────┘   └──────────────────────┘   └─────────────────────┘   │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Unity Catalog (Tables/Schemas)                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Authentication Pattern (SDK Auto-Auth)

### The Correct Pattern for Databricks Apps

Databricks Apps use **SDK auto-authentication** - the app's Service Principal identity is automatically used when running inside Databricks. Do NOT use OBO (On-Behalf-Of) token pattern.

```python
# backend/routers/your_ai_router.py

from databricks.sdk import WorkspaceClient
from databricks.sdk.config import Config
import os

# Global state
_workspace_client = None
_auth_mode = None

# Fallback token for local development
DATABRICKS_TOKEN = os.getenv("DATABRICKS_TOKEN")
DATABRICKS_HOST = os.getenv("DATABRICKS_HOST")
LLM_MODEL_ID = "databricks-meta-llama-4-maverick"  # Your model endpoint

def _init_auth():
    """Initialize authentication - SDK auto-auth for Databricks Apps, token fallback for local."""
    global _workspace_client, _auth_mode

    if _auth_mode is not None:
        return  # Already initialized

    try:
        # SDK auto-auth works when running inside Databricks Apps
        config = Config(http_timeout_seconds=120)
        _workspace_client = WorkspaceClient(config=config)
        _auth_mode = "sdk"
        logger.info("Initialized with SDK auto-auth")
    except Exception as e:
        logger.warning(f"SDK auth failed, trying token fallback: {e}")
        if DATABRICKS_TOKEN:
            _auth_mode = "token"
            logger.info("Using token-based authentication")
        else:
            _auth_mode = None
            logger.error("No authentication method available")


def call_llm(messages: list, max_tokens: int = 2000, temperature: float = 0.7) -> dict:
    """
    Unified LLM call function with SDK auth and token fallback.
    Returns: {"content": str, "model": str, "fallback": bool}
    """
    _init_auth()

    if _auth_mode == "sdk" and _workspace_client:
        # SDK auth - use workspace client's API
        api_url = f"/serving-endpoints/{LLM_MODEL_ID}/invocations"
        payload = {
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature
        }

        response = _workspace_client.api_client.do("POST", api_url, body=payload)

        # Extract content from response
        if isinstance(response, dict):
            choices = response.get("choices", [])
            if choices:
                content = choices[0].get("message", {}).get("content", "")
                return {"content": content, "model": LLM_MODEL_ID, "fallback": False}

        return {"content": str(response), "model": LLM_MODEL_ID, "fallback": False}

    elif _auth_mode == "token" and DATABRICKS_TOKEN:
        # Token fallback - use OpenAI client
        from openai import OpenAI

        client = OpenAI(
            api_key=DATABRICKS_TOKEN,
            base_url=f"{DATABRICKS_HOST}/serving-endpoints"
        )

        response = client.chat.completions.create(
            model=LLM_MODEL_ID,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature
        )

        return {
            "content": response.choices[0].message.content,
            "model": LLM_MODEL_ID,
            "fallback": False
        }

    else:
        # No LLM available - return fallback response
        return {
            "content": "AI analysis unavailable. Please try again later.",
            "model": "Fallback",
            "fallback": True
        }
```

---

## 2. Async AI Request Queue

### Backend: Async Router (`/api/ai/async/*`)

```python
# backend/routers/async_ai.py

from fastapi import APIRouter, BackgroundTasks
from pydantic import BaseModel
from enum import Enum
from datetime import datetime
import uuid

router = APIRouter(prefix="/api/ai", tags=["async-ai"])

class RequestType(str, Enum):
    PERFORMANCE_INSIGHT = "performance_insight"
    DOMAIN_QUESTION = "domain_question"  # e.g., ARIA questions
    GENIE_QUERY = "genie_query"

class RequestStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

# In-memory store (use Redis/DB in production)
_ai_requests: dict = {}

class AIRequest(BaseModel):
    request_type: RequestType
    payload: dict
    title: str  # Short description for notification

@router.post("/async/submit")
async def submit_async_request(request: AIRequest, background_tasks: BackgroundTasks):
    """Submit an async AI request. Returns immediately with request_id."""
    request_id = str(uuid.uuid4())[:8]

    _ai_requests[request_id] = {
        "id": request_id,
        "type": request.request_type,
        "title": request.title,
        "payload": request.payload,
        "status": RequestStatus.PENDING,
        "created_at": datetime.now().isoformat(),
        "completed_at": None,
        "result": None,
        "error": None,
        "seen": False,
    }

    # Start background processing
    background_tasks.add_task(process_ai_request, request_id)

    return {
        "status": "success",
        "data": {
            "request_id": request_id,
            "status": RequestStatus.PENDING,
            "title": request.title,
            "message": "Request submitted. You can navigate away and check back for results."
        }
    }

@router.get("/async/pending")
async def get_pending_requests():
    """Get all pending/processing and unseen completed requests for polling."""
    pending = []
    ready = []

    for request_id, data in _ai_requests.items():
        if data["status"] in [RequestStatus.PENDING, RequestStatus.PROCESSING]:
            pending.append({
                "id": data["id"],
                "type": data["type"],
                "title": data["title"],
                "status": data["status"],
                "created_at": data["created_at"]
            })
        elif data["status"] == RequestStatus.COMPLETED and not data["seen"]:
            ready.append({
                "id": data["id"],
                "type": data["type"],
                "title": data["title"],
                "status": data["status"],
                "completed_at": data["completed_at"]
            })

    return {
        "status": "success",
        "data": {
            "pending_count": len(pending),
            "ready_count": len(ready),
            "pending": pending,
            "ready": ready,
            "total_unseen": len(pending) + len(ready)
        }
    }

@router.get("/async/result/{request_id}")
async def get_request_result(request_id: str):
    """Get the result of a completed async request."""
    if request_id not in _ai_requests:
        return {"status": "error", "message": f"Request {request_id} not found"}

    data = _ai_requests[request_id]
    data["seen"] = True  # Mark as seen

    if data["status"] != RequestStatus.COMPLETED:
        return {"status": "pending", "data": {"status": data["status"]}}

    return {
        "status": "success",
        "data": {
            "id": data["id"],
            "result": data["result"],
            "completed_at": data["completed_at"]
        }
    }

async def process_ai_request(request_id: str):
    """Background task to process AI request."""
    if request_id not in _ai_requests:
        return

    data = _ai_requests[request_id]
    data["status"] = RequestStatus.PROCESSING

    try:
        request_type = data["type"]
        payload = data["payload"]

        if request_type == RequestType.PERFORMANCE_INSIGHT:
            result = await process_performance_insight(payload)
        elif request_type == RequestType.DOMAIN_QUESTION:
            result = await process_domain_question(payload)
        elif request_type == RequestType.GENIE_QUERY:
            result = await process_genie_query(payload)
        else:
            raise ValueError(f"Unknown request type: {request_type}")

        data["status"] = RequestStatus.COMPLETED
        data["result"] = result
        data["completed_at"] = datetime.now().isoformat()

    except Exception as e:
        data["status"] = RequestStatus.FAILED
        data["error"] = str(e)
        data["completed_at"] = datetime.now().isoformat()
```

### Frontend: AsyncAIContext

```tsx
// frontend/src/contexts/AsyncAIContext.tsx

import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react'

interface AIRequest {
  id: string
  type: string
  title: string
  status: 'pending' | 'processing' | 'completed' | 'failed'
  created_at: string
  completed_at?: string
  result?: any
  seen: boolean
}

interface AsyncAIContextType {
  pendingRequests: AIRequest[]
  readyRequests: AIRequest[]
  totalUnseen: number
  submitRequest: (type: string, title: string, payload: any) => Promise<string>
  getResult: (requestId: string) => Promise<any>
  markSeen: (requestId: string) => void
  preloadInsights: (items: any[]) => void
  getCachedInsight: (itemId: string) => any | null
  isPolling: boolean
}

const AsyncAIContext = createContext<AsyncAIContextType | null>(null)

export const useAsyncAI = () => {
  const context = useContext(AsyncAIContext)
  if (!context) {
    throw new Error('useAsyncAI must be used within an AsyncAIProvider')
  }
  return context
}

export const AsyncAIProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [pendingRequests, setPendingRequests] = useState<AIRequest[]>([])
  const [readyRequests, setReadyRequests] = useState<AIRequest[]>([])
  const [isPolling, setIsPolling] = useState(false)

  // Cache for preloaded insights
  const insightCache = useRef<Map<string, any>>(new Map())
  const requestToItemMap = useRef<Map<string, string>>(new Map())

  const totalUnseen = pendingRequests.length + readyRequests.filter(r => !r.seen).length

  // Polling function
  const pollForUpdates = useCallback(async () => {
    try {
      const response = await fetch('/api/ai/async/pending')
      const data = await response.json()

      if (data.status === 'success') {
        setPendingRequests(data.data.pending || [])

        // Merge new ready requests
        const newReady = data.data.ready || []
        setReadyRequests(prev => {
          const existingIds = new Set(prev.map(r => r.id))
          const newItems = newReady.filter((r: AIRequest) => !existingIds.has(r.id))
          return [...prev, ...newItems]
        })

        // Update insight cache for completed requests
        for (const ready of newReady) {
          const itemId = requestToItemMap.current.get(ready.id)
          if (itemId && ready.status === 'completed') {
            const resultResponse = await fetch(`/api/ai/async/result/${ready.id}`)
            const resultData = await resultResponse.json()
            if (resultData.status === 'success' && resultData.data.result) {
              insightCache.current.set(itemId, resultData.data.result)
            }
          }
        }
      }
    } catch (error) {
      console.error('Error polling for AI updates:', error)
    }
  }, [])

  // Dynamic polling interval: 2s when pending, 30s otherwise
  useEffect(() => {
    const hasPending = pendingRequests.length > 0
    const pollInterval = hasPending ? 2000 : 30000

    setIsPolling(hasPending)
    const interval = setInterval(pollForUpdates, pollInterval)

    return () => clearInterval(interval)
  }, [pendingRequests.length, pollForUpdates])

  // Initial poll on mount
  useEffect(() => {
    pollForUpdates()
  }, [pollForUpdates])

  const submitRequest = useCallback(async (type: string, title: string, payload: any): Promise<string> => {
    const response = await fetch('/api/ai/async/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ request_type: type, title, payload })
    })

    const data = await response.json()
    if (data.status === 'success') {
      await pollForUpdates()
      return data.data.request_id
    }
    throw new Error(data.message || 'Failed to submit request')
  }, [pollForUpdates])

  const preloadInsights = useCallback(async (items: any[]) => {
    for (const item of items) {
      if (insightCache.current.has(item.id)) continue

      try {
        const requestId = await submitRequest(
          'performance_insight',
          item.headline || item.title,
          { item_id: item.id, ...item }
        )
        requestToItemMap.current.set(requestId, item.id)
      } catch (error) {
        console.error(`Failed to preload item ${item.id}:`, error)
      }
    }
  }, [submitRequest])

  const getCachedInsight = useCallback((itemId: string): any | null => {
    return insightCache.current.get(itemId) || null
  }, [])

  // ... rest of implementation
}
```

---

## 3. LLM Status Indicator (Green/Orange Dot)

The UI shows a small colored dot indicating LLM status:
- **Green dot** = Live LLM response from Databricks model serving
- **Orange dot** = Fallback mode (LLM unavailable, using cached/template response)

### Implementation

```tsx
// Component showing LLM status indicator

interface AIResponseProps {
  model: string | null  // Contains "Fallback" if fallback mode
  content: string
}

const AIResponseIndicator: React.FC<AIResponseProps> = ({ model }) => {
  const isFallback = model?.includes('Fallback')

  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 0.5,
        px: 0.75,
        py: 0.25,
        borderRadius: 1,
        bgcolor: isFallback ? 'rgba(255, 152, 0, 0.15)' : 'rgba(76, 175, 80, 0.15)',
        border: `1px solid ${isFallback ? '#FF9800' : '#4CAF50'}`,
      }}
      title={isFallback ? 'Fallback Mode - LLM unavailable' : 'Live LLM Response'}
    >
      {/* Status dot */}
      <Box
        sx={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          bgcolor: isFallback ? '#FF9800' : '#4CAF50',
        }}
      />
      {/* Status text */}
      <Typography
        variant="caption"
        sx={{
          fontSize: '0.65rem',
          fontWeight: 600,
          color: isFallback ? '#FF9800' : '#4CAF50',
        }}
      >
        {isFallback ? 'FB' : 'LLM'}
      </Typography>
    </Box>
  )
}
```

---

## 4. AI Notification Badge

Header component showing pending/ready AI requests:

```tsx
// frontend/src/components/AINotificationBadge.tsx

import { Badge, IconButton, Popover, List, ListItem, Chip, CircularProgress } from '@mui/material'
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome'
import { useAsyncAI } from '../contexts/AsyncAIContext'

export const AINotificationBadge: React.FC = () => {
  const { pendingRequests, readyRequests, totalUnseen, getResult, markSeen, isPolling } = useAsyncAI()
  const [anchorEl, setAnchorEl] = useState<HTMLButtonElement | null>(null)

  const allRequests = [
    ...pendingRequests.map(r => ({ ...r, status: r.status || 'pending' })),
    ...readyRequests.filter(r => !r.seen).map(r => ({ ...r, status: 'completed' })),
  ]

  return (
    <>
      <IconButton onClick={(e) => setAnchorEl(e.currentTarget)} sx={{ position: 'relative' }}>
        <Badge
          badgeContent={totalUnseen}
          color={pendingRequests.length > 0 ? 'warning' : 'success'}
          max={99}
        >
          <AutoAwesomeIcon />
        </Badge>

        {/* Spinning indicator when polling */}
        {isPolling && (
          <CircularProgress
            size={32}
            sx={{
              position: 'absolute',
              top: 4,
              left: 4,
              opacity: 0.5,
            }}
          />
        )}
      </IconButton>

      <Popover open={Boolean(anchorEl)} anchorEl={anchorEl} onClose={() => setAnchorEl(null)}>
        {/* Popover content showing request list */}
        <List>
          {allRequests.map((request) => (
            <ListItem
              key={request.id}
              onClick={() => request.status === 'completed' && handleViewResult(request)}
              sx={{ cursor: request.status === 'completed' ? 'pointer' : 'default' }}
            >
              {/* Request status icons and details */}
            </ListItem>
          ))}
        </List>
      </Popover>
    </>
  )
}
```

---

## 5. Floating AI Assistant (Chat Widget)

A draggable floating action button (FAB) that opens a chat interface with Genie integration.

### Features

- **Draggable FAB**: Users can move the button anywhere on screen
- **Animated Attention Getter**: Pulse animation and callout on first load
- **Expandable Dialog**: Opens in modal, can go full-screen
- **Genie Integration**: Uses GenieChatCore for natural language SQL queries
- **Multiple Genie Spaces**: Users can select different data domains

### Implementation

```tsx
// frontend/src/components/FloatingAIAssistant.tsx

import { useState, useRef, useEffect, useCallback } from 'react'
import { Box, Fab, Dialog, IconButton, Tooltip, Zoom } from '@mui/material'
import { AutoAwesome, Close, OpenInFull, CloseFullscreen, DragIndicator } from '@mui/icons-material'
import { motion, AnimatePresence } from 'framer-motion'
import { GenieChatCore } from './GenieChat'

function FloatingAIAssistant({ onExpandToFullPage }: { onExpandToFullPage?: () => void }) {
  const [isOpen, setIsOpen] = useState(false)
  const [isExpanded, setIsExpanded] = useState(false)
  const [position, setPosition] = useState({ x: 0, y: 0 })
  const [isDragging, setIsDragging] = useState(false)
  const [showPulse, setShowPulse] = useState(true)
  const [showAnnotation, setShowAnnotation] = useState(true)
  const dragStartPos = useRef({ x: 0, y: 0 })
  const initialPosition = useRef({ x: 0, y: 0 })

  // Initialize position on mount (bottom-left corner)
  useEffect(() => {
    setPosition({ x: 20, y: window.innerHeight - 150 })

    // Stop pulsing after 10 seconds
    const pulseTimer = setTimeout(() => setShowPulse(false), 10000)
    // Hide annotation after 15 seconds
    const annotationTimer = setTimeout(() => setShowAnnotation(false), 15000)
    return () => {
      clearTimeout(pulseTimer)
      clearTimeout(annotationTimer)
    }
  }, [])

  // Handle mouse events for dragging
  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return
    e.preventDefault()
    setIsDragging(true)
    dragStartPos.current = { x: e.clientX, y: e.clientY }
    initialPosition.current = { ...position }
  }, [position])

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isDragging) return
      const deltaX = e.clientX - dragStartPos.current.x
      const deltaY = e.clientY - dragStartPos.current.y
      const newX = Math.max(20, Math.min(window.innerWidth - 80, initialPosition.current.x + deltaX))
      const newY = Math.max(80, Math.min(window.innerHeight - 80, initialPosition.current.y + deltaY))
      setPosition({ x: newX, y: newY })
    }

    const handleMouseUp = () => setIsDragging(false)

    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove)
      window.addEventListener('mouseup', handleMouseUp)
    }
    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleMouseUp)
    }
  }, [isDragging])

  return (
    <>
      {/* Floating Action Button with Pulse Animation */}
      <Box
        sx={{
          position: 'fixed',
          left: position.x,
          top: position.y,
          zIndex: 1200,
          cursor: isDragging ? 'grabbing' : 'grab',
        }}
        onMouseDown={handleMouseDown}
      >
        <AnimatePresence>
          {!isOpen && (
            <motion.div
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0, opacity: 0 }}
              transition={{ type: 'spring', stiffness: 260, damping: 20 }}
            >
              <Tooltip title="Ask Me - Drag to move">
                <Box sx={{ position: 'relative' }}>
                  {/* Pulse rings */}
                  {showPulse && (
                    <Box
                      sx={{
                        position: 'absolute',
                        inset: -4,
                        borderRadius: '50%',
                        backgroundColor: '#C8102E',
                        opacity: 0.3,
                        animation: 'pulse 2s infinite',
                        '@keyframes pulse': {
                          '0%': { transform: 'scale(1)', opacity: 0.3 },
                          '50%': { transform: 'scale(1.3)', opacity: 0 },
                          '100%': { transform: 'scale(1)', opacity: 0.3 },
                        },
                      }}
                    />
                  )}

                  {/* Main FAB */}
                  <Fab
                    color="secondary"
                    onClick={() => !isDragging && setIsOpen(true)}
                    sx={{
                      width: 56,
                      height: 56,
                      boxShadow: '0 4px 20px rgba(200, 16, 46, 0.4)',
                      background: 'linear-gradient(135deg, #C8102E 0%, #E53935 100%)',
                      '&:hover': {
                        boxShadow: '0 6px 25px rgba(200, 16, 46, 0.5)',
                        transform: 'scale(1.05)',
                      },
                    }}
                  >
                    <AutoAwesome sx={{ fontSize: 28 }} />
                  </Fab>

                  {/* Drag handle indicator */}
                  <Box
                    sx={{
                      position: 'absolute',
                      top: -8,
                      right: -8,
                      width: 20,
                      height: 20,
                      borderRadius: '50%',
                      backgroundColor: '#002E6D',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <DragIndicator sx={{ fontSize: 12, color: 'white' }} />
                  </Box>

                  {/* Animated callout annotation */}
                  {showAnnotation && (
                    <motion.div
                      initial={{ opacity: 0, x: -30 }}
                      animate={{ opacity: 1, x: 0, y: [0, -8, 0] }}
                      transition={{ y: { duration: 1.2, repeat: Infinity, ease: "easeInOut" } }}
                      style={{ position: 'absolute', left: 75, top: '50%', transform: 'translateY(-50%)' }}
                    >
                      <Box sx={{ background: 'linear-gradient(135deg, #C8102E, #E53935)', color: 'white', px: 3, py: 2, borderRadius: 3 }}>
                        <Typography variant="body1" sx={{ fontWeight: 700 }}>
                          Ask me anything!
                        </Typography>
                        <Typography variant="body2">Your AI Assistant</Typography>
                      </Box>
                    </motion.div>
                  )}
                </Box>
              </Tooltip>
            </motion.div>
          )}
        </AnimatePresence>
      </Box>

      {/* Chat Dialog */}
      <Dialog
        open={isOpen}
        onClose={() => setIsOpen(false)}
        maxWidth={isExpanded ? 'xl' : 'md'}
        fullWidth
        fullScreen={isExpanded}
        TransitionComponent={Zoom}
        PaperProps={{
          sx: {
            borderRadius: isExpanded ? 0 : 3,
            maxHeight: isExpanded ? '100vh' : '85vh',
            height: isExpanded ? '100vh' : '85vh',
          },
        }}
      >
        <DialogTitle sx={{ background: 'linear-gradient(135deg, #002E6D 0%, #004B93 100%)', color: 'white' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
              <AutoAwesome />
              <Typography variant="h6">Ask Me</Typography>
            </Box>
            <Box>
              <IconButton onClick={() => setIsExpanded(!isExpanded)} sx={{ color: 'white' }}>
                {isExpanded ? <CloseFullscreen /> : <OpenInFull />}
              </IconButton>
              <IconButton onClick={() => setIsOpen(false)} sx={{ color: 'white' }}>
                <Close />
              </IconButton>
            </Box>
          </Box>
        </DialogTitle>

        <DialogContent sx={{ p: 0, backgroundColor: '#F5F7FA' }}>
          <GenieChatCore compact={true} />
        </DialogContent>
      </Dialog>
    </>
  )
}
```

### Genie Chat Core Component

The `GenieChatCore` component provides:

- **Genie Space Selector**: Dropdown to select different data domains (USA Spending, Border Security, Personnel, etc.)
- **Natural Language Queries**: Users ask questions in plain English
- **SQL Generation**: Genie converts questions to SQL and executes against data warehouse
- **Data Visualization**: Results displayed as tables, bar charts, pie charts, or line charts
- **Collapsible SQL View**: Users can see the generated SQL query
- **Multi-Agent Trace**: Shows reasoning steps when using Multi-Agent Service

### Genie Space Configuration

```tsx
// Available Genie Spaces (configured in backend)
const GENIE_SPACES = [
  { key: 'usa_spending', id: '01f0dbb6755f18b8a54b646f2c576467', name: 'USA Spending Analytics' },
  { key: 'dashboard', id: '01f0dbb675b41dbaa386170b8a13596c', name: 'Dashboard & Operations' },
  { key: 'border_security', id: '01f0dbb67601102f8a43dc14110f032d', name: 'Border Security (CBP)' },
  { key: 'ice', id: '01f0dbb6764a14ea84b2994dd474aeab', name: 'ICE Operations' },
  { key: 'cybersecurity', id: '01f0dbb676981919b05f43ef8239ad8b', name: 'Cybersecurity (CISA)' },
  { key: 'personnel', id: '01f0dbb676e912c8ac547eafcb62dd84', name: 'Personnel & Hiring' },
  { key: 'compliance', id: '01f0dbb6773518b4bf0a87a2e51f6a11', name: 'Compliance & Audit' },
  { key: 'law_enforcement', id: '01f0dbb6778a10ebb81ec2f5a23340eb', name: 'Law Enforcement' },
]
```

### Backend Genie Router

```python
# backend/routers/genie.py

from fastapi import APIRouter
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.dashboards import GenieMessage

router = APIRouter(prefix="/api/genie", tags=["genie"])

@router.get("/spaces")
async def get_genie_spaces():
    """Return available Genie spaces for the dropdown."""
    return {
        "spaces": [
            {"key": "usa_spending", "id": "...", "name": "USA Spending Analytics", "sample_questions": [...]},
            # ... other spaces
        ]
    }

@router.post("/chat")
async def genie_chat(space_id: str, question: str, conversation_id: str = None):
    """
    Send a question to a Genie space and return the response.
    Creates a new conversation or continues an existing one.
    """
    client = WorkspaceClient()

    if conversation_id:
        # Continue existing conversation
        result = client.genie.create_message(
            space_id=space_id,
            conversation_id=conversation_id,
            content=question
        )
    else:
        # Start new conversation
        result = client.genie.start_conversation(
            space_id=space_id,
            content=question
        )

    # Poll for completion
    message = poll_for_completion(client, space_id, result.conversation_id, result.message_id)

    return {
        "conversation_id": result.conversation_id,
        "response": extract_response(message),
        "sql": extract_sql(message),
        "data": extract_data(message),
    }
```

---

## 6. Markdown Rendering

AI responses are rendered as formatted Markdown with custom styling:

```tsx
// Using react-markdown with remark-gfm for GitHub-flavored markdown

import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

<Box
  sx={{
    // Heading styles
    '& h2': {
      color: '#002E6D',
      fontSize: '1.25rem',
      fontWeight: 700,
      mt: 3,
      mb: 1.5,
      borderBottom: '2px solid #002E6D',
      pb: 0.5,
    },
    '& h3': {
      color: '#0066CC',
      fontSize: '1.1rem',
      fontWeight: 600,
      mt: 2,
      mb: 1,
    },

    // List styles
    '& ul, & ol': { pl: 2, mb: 2 },
    '& li': { mb: 1, lineHeight: 1.6 },
    '& p': { mb: 1.5, lineHeight: 1.7 },
    '& strong': { color: '#002E6D' },

    // Table styles (for Genie SQL results)
    '& table': {
      width: '100%',
      borderCollapse: 'collapse',
      mb: 2,
      border: '1px solid rgba(0, 46, 109, 0.3)',
    },
    '& thead': {
      backgroundColor: '#002E6D',
      color: 'white',
    },
    '& th': {
      padding: '12px 16px',
      textAlign: 'left',
      fontWeight: 700,
    },
    '& td': {
      padding: '10px 16px',
      borderBottom: '1px solid rgba(0, 46, 109, 0.15)',
    },
    '& tbody tr:nth-of-type(even)': {
      backgroundColor: 'rgba(0, 46, 109, 0.03)',
    },
    '& tbody tr:hover': {
      backgroundColor: 'rgba(0, 46, 109, 0.08)',
    },

    // Code styles
    '& code': {
      backgroundColor: '#F5F5F5',
      padding: '2px 6px',
      borderRadius: 1,
      fontSize: '0.85em',
      fontFamily: 'monospace',
    },
    '& pre': {
      backgroundColor: '#F5F5F5',
      padding: 2,
      borderRadius: 1,
      overflow: 'auto',
    },

    // Blockquote styles
    '& blockquote': {
      borderLeft: '4px solid #0066CC',
      pl: 2,
      ml: 0,
      fontStyle: 'italic',
    },
  }}
>
  <ReactMarkdown remarkPlugins={[remarkGfm]}>
    {aiResponse.content}
  </ReactMarkdown>
</Box>
```

---

## 6. Genie SQL Integration

### Calling Genie from Backend

```python
# backend/services/genie_service.py

from databricks.sdk import WorkspaceClient
from databricks.sdk.service.dashboards import GenieMessage
import time

GENIE_SPACE_ID = "your-genie-space-id"

def ask_genie(question: str, timeout_seconds: int = 120) -> dict:
    """
    Query Databricks Genie with natural language and get SQL-generated results.
    """
    _init_auth()  # Initialize SDK auth

    if not _workspace_client:
        return {"error": "Genie not available", "fallback": True}

    try:
        genie = _workspace_client.genie

        # Start a new conversation
        conversation = genie.start_conversation(
            space_id=GENIE_SPACE_ID,
            content=question
        )

        conversation_id = conversation.conversation_id
        message_id = conversation.message_id

        # Poll for completion
        start_time = time.time()
        while time.time() - start_time < timeout_seconds:
            result = genie.get_message(
                space_id=GENIE_SPACE_ID,
                conversation_id=conversation_id,
                message_id=message_id
            )

            if result.status == "COMPLETED":
                # Extract the response
                return {
                    "status": "success",
                    "answer": extract_genie_response(result),
                    "sql_query": extract_sql_query(result),
                    "data": extract_data_table(result),
                    "fallback": False
                }

            elif result.status == "FAILED":
                return {
                    "status": "error",
                    "error": result.error_message or "Genie query failed",
                    "fallback": True
                }

            time.sleep(2)  # Poll every 2 seconds

        return {"status": "error", "error": "Timeout", "fallback": True}

    except Exception as e:
        logger.error(f"Genie query failed: {e}")
        return {"status": "error", "error": str(e), "fallback": True}


def extract_genie_response(result) -> str:
    """Extract text response from Genie result."""
    for attachment in result.attachments or []:
        if attachment.text:
            return attachment.text.content
    return ""

def extract_sql_query(result) -> str:
    """Extract generated SQL from Genie result."""
    for attachment in result.attachments or []:
        if attachment.query:
            return attachment.query.query
    return ""

def extract_data_table(result) -> list:
    """Extract data table from Genie result as list of dicts."""
    # Implementation depends on Genie response structure
    pass
```

### Frontend: Genie Integration in Chat

```tsx
// In your AI assistant component

const handleGenieQuery = async (question: string) => {
  setLoading(true)

  try {
    const response = await fetch('/api/genie/query', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question })
    })

    const data = await response.json()

    if (data.status === 'success') {
      // Format response with SQL and data
      const formattedResponse = `
## Query Results

${data.answer}

${data.sql_query ? `### Generated SQL
\`\`\`sql
${data.sql_query}
\`\`\`` : ''}

${data.data ? formatDataAsMarkdownTable(data.data) : ''}
`
      setResponse({ content: formattedResponse, model: 'Genie + LLM' })
    }
  } catch (error) {
    setError('Failed to query Genie')
  } finally {
    setLoading(false)
  }
}
```

---

## 7. Service Principal Permissions (CRITICAL)

### Required Permissions for Databricks Apps

When deploying to Databricks, the app's Service Principal needs these permissions:

#### A. Model Serving Endpoints

```bash
# Grant CAN_QUERY permission on serving endpoints
databricks permissions update serving-endpoints/<endpoint-name> \
  --json '{
    "access_control_list": [
      {
        "service_principal_name": "<your-app-sp-name>",
        "permission_level": "CAN_QUERY"
      }
    ]
  }'
```

#### B. Genie Spaces

```bash
# Grant CAN_RUN permission on Genie space
databricks permissions update genie-space/<space-id> \
  --json '{
    "access_control_list": [
      {
        "service_principal_name": "<your-app-sp-name>",
        "permission_level": "CAN_RUN"
      }
    ]
  }'
```

#### C. SQL Warehouses

```bash
# Grant CAN_USE permission on SQL warehouse used by Genie
databricks permissions update warehouses/<warehouse-id> \
  --json '{
    "access_control_list": [
      {
        "service_principal_name": "<your-app-sp-name>",
        "permission_level": "CAN_USE"
      }
    ]
  }'
```

#### D. Unity Catalog (Tables/Schemas/Catalogs)

```sql
-- Grant SELECT on catalog
GRANT USE CATALOG ON CATALOG <catalog_name> TO `<service-principal-application-id>`;

-- Grant SELECT on schema
GRANT USE SCHEMA ON SCHEMA <catalog>.<schema> TO `<service-principal-application-id>`;

-- Grant SELECT on tables
GRANT SELECT ON TABLE <catalog>.<schema>.<table> TO `<service-principal-application-id>`;

-- Or grant on all tables in schema
GRANT SELECT ON SCHEMA <catalog>.<schema> TO `<service-principal-application-id>`;
```

### Finding Your App's Service Principal

```bash
# List apps and find your app's SP
databricks apps list

# Get app details including service principal
databricks apps get <app-name>

# The service principal name is typically: apps/<app-name>
```

### Terraform Example

```hcl
# If using Terraform for permissions

resource "databricks_permissions" "llm_endpoint" {
  serving_endpoint_id = databricks_model_serving.llm.id

  access_control {
    service_principal_name = "apps/your-app-name"
    permission_level       = "CAN_QUERY"
  }
}

resource "databricks_permissions" "genie_space" {
  genie_space_id = var.genie_space_id

  access_control {
    service_principal_name = "apps/your-app-name"
    permission_level       = "CAN_RUN"
  }
}

resource "databricks_permissions" "sql_warehouse" {
  sql_endpoint_id = var.warehouse_id

  access_control {
    service_principal_name = "apps/your-app-name"
    permission_level       = "CAN_USE"
  }
}

resource "databricks_grants" "catalog" {
  catalog = var.catalog_name

  grant {
    principal  = var.app_service_principal_id
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "schema" {
  schema = "${var.catalog_name}.${var.schema_name}"

  grant {
    principal  = var.app_service_principal_id
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
```

---

## 8. Multi-Agent Service (MAS) Integration

For complex multi-step AI tasks, use the Multi-Agent Service pattern:

```python
# backend/services/multi_agent_service.py

from databricks.sdk import WorkspaceClient
from databricks.sdk.config import Config
import json

class MultiAgentService:
    def __init__(self):
        config = Config(http_timeout_seconds=300)  # Longer timeout for multi-agent
        self.client = WorkspaceClient(config=config)
        self.endpoint_name = "your-agent-endpoint"

    async def run_agent(self, task: str, context: dict) -> dict:
        """
        Execute a multi-agent task.
        """
        try:
            api_url = f"/serving-endpoints/{self.endpoint_name}/invocations"

            payload = {
                "task": task,
                "context": context,
                "config": {
                    "max_iterations": 10,
                    "timeout_seconds": 120
                }
            }

            response = self.client.api_client.do("POST", api_url, body=payload)

            return {
                "status": "success",
                "result": response.get("result"),
                "steps": response.get("steps", []),
                "model": self.endpoint_name
            }

        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "fallback": True
            }
```

---

## 9. File Reference

| Component | File Path | Purpose |
|-----------|-----------|---------|
| Async AI Router | `backend/routers/async_ai.py` | Request queue & background processing |
| LLM Service | `backend/routers/congressional.py` | SDK auth & LLM calls |
| Genie Service | `backend/services/genie_service.py` | Genie SQL integration |
| Multi-Agent Service | `backend/services/multi_agent_service.py` | Complex AI tasks |
| AsyncAIContext | `frontend/src/contexts/AsyncAIContext.tsx` | React state management |
| AINotificationBadge | `frontend/src/components/AINotificationBadge.tsx` | Header badge UI |
| Floating AI Assistant | `frontend/src/components/FloatingAIAssistant.tsx` | Chat widget |
| Domain AI Component | `frontend/src/components/CongressionalPrepTab.tsx` | ARIA implementation |

---

## 10. Troubleshooting

### Common Issues

1. **"SDK auth failed"**: Check that app is deployed to Databricks and SP has permissions
2. **"Permission denied on serving endpoint"**: Grant CAN_QUERY to SP
3. **"Genie query timeout"**: Check warehouse is running, increase timeout
4. **"Table not found"**: Grant Unity Catalog permissions to SP
5. **"Fallback mode always active"**: Check DATABRICKS_HOST/TOKEN env vars for local dev

### Debug Logging

```python
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Log auth mode
logger.info(f"Auth mode: {_auth_mode}")
logger.info(f"Workspace client: {_workspace_client is not None}")
```

---

## Quick Start Checklist

- [ ] Deploy app to Databricks
- [ ] Grant SP `CAN_QUERY` on model serving endpoints
- [ ] Grant SP `CAN_RUN` on Genie spaces (if using Genie)
- [ ] Grant SP `CAN_USE` on SQL warehouses
- [ ] Grant SP Unity Catalog permissions (USE_CATALOG, USE_SCHEMA, SELECT)
- [ ] Set environment variables for local development
- [ ] Test LLM endpoint connectivity
- [ ] Verify green dot appears in UI (not orange)
