"use client"

import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Clock, Database, GitBranch, Zap, Search, Activity } from 'lucide-react'

interface StreamEvent {
  id: string
  type: 'command' | 'event' | 'query' | 'saga'
  name: string
  service: string
  timestamp: string
  data?: any
  duration?: number
  status?: 'success' | 'error' | 'pending'
}

const typeConfig = {
  command: {
    color: 'bg-green-500',
    icon: <Zap className="w-3 h-3" />,
    label: 'Command',
  },
  event: {
    color: 'bg-orange-500',
    icon: <Database className="w-3 h-3" />,
    label: 'Event',
  },
  query: {
    color: 'bg-purple-500',
    icon: <Search className="w-3 h-3" />,
    label: 'Query',
  },
  saga: {
    color: 'bg-red-500',
    icon: <GitBranch className="w-3 h-3" />,
    label: 'Saga',
  },
}

export function EventStream({ events = [], title = "Event Stream" }: { events?: StreamEvent[], title?: string }) {
  const sortedEvents = [...events].sort((a, b) => 
    new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
  ).slice(0, 100)

  return (
    <Card className="h-full">
      <CardHeader className="pb-3">
        <CardTitle className="text-lg flex items-center gap-2">
          <Activity className="w-5 h-5" />
          {title}
          <Badge variant="secondary" className="ml-auto">
            {events.length} events
          </Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <ScrollArea className="h-[500px] px-4">
          <AnimatePresence mode="popLayout">
            {sortedEvents.map((event, index) => (
              <motion.div
                key={event.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                transition={{ duration: 0.2, delay: index * 0.02 }}
                className="mb-3 last:mb-0"
              >
                <div className="flex items-start gap-3 p-3 rounded-lg border bg-card hover:bg-accent/50 transition-colors">
                  <div className={`p-2 rounded-full ${typeConfig[event.type].color} text-white`}>
                    {typeConfig[event.type].icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold text-sm truncate">
                        {event.name}
                      </span>
                      {event.status && (
                        <Badge 
                          variant={event.status === 'success' ? 'default' : event.status === 'error' ? 'destructive' : 'secondary'}
                          className="text-xs"
                        >
                          {event.status}
                        </Badge>
                      )}
                    </div>
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span>{event.service}</span>
                      <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {new Date(event.timestamp).toLocaleTimeString()}
                      </span>
                      {event.duration && (
                        <span>{event.duration}ms</span>
                      )}
                    </div>
                    {event.data && (
                      <div className="mt-2 p-2 bg-muted/50 rounded text-xs font-mono overflow-x-auto">
                        {JSON.stringify(event.data, null, 2)}
                      </div>
                    )}
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </ScrollArea>
      </CardContent>
    </Card>
  )
}