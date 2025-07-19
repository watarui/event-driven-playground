"use client"

import React from 'react'

interface SimpleCodeEditorProps {
  value: string
  onChange: (value: string) => void
  language?: 'json' | 'graphql'
  placeholder?: string
  height?: string
  readOnly?: boolean
  theme?: 'light' | 'dark'
}

export default function SimpleCodeEditor({
  value,
  onChange,
  language = 'json',
  placeholder,
  height = '200px',
  readOnly = false,
  theme = 'dark'
}: SimpleCodeEditorProps) {
  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    if (!readOnly) {
      onChange(e.target.value)
    }
  }

  return (
    <textarea
      value={value}
      onChange={handleChange}
      className={`
        w-full p-3 font-mono text-sm border rounded-md
        ${theme === 'dark' ? 'bg-gray-900 text-gray-100 border-gray-700' : 'bg-gray-50 text-gray-900 border-gray-300'}
        ${readOnly ? 'cursor-default' : 'cursor-text'}
        focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
        resize-none
      `}
      style={{ 
        height,
        fontFamily: "'JetBrains Mono', Consolas, Monaco, 'Courier New', monospace"
      }}
      placeholder={placeholder}
      readOnly={readOnly}
      spellCheck={false}
    />
  )
}