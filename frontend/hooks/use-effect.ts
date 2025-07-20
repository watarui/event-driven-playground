import { Effect, Exit, Layer, ManagedRuntime, Runtime } from "effect"
import { useEffect, useState } from "react"
import { AppLayer } from "@/lib/effects/monitoring"

// Create runtime with our services
const runtime = ManagedRuntime.make(AppLayer)

export function useEffectProgram<A, E>(
  program: Effect.Effect<A, E>,
  deps: React.DependencyList = []
) {
  const [data, setData] = useState<A | null>(null)
  const [error, setError] = useState<E | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    const runProgram = async () => {
      setLoading(true)
      setError(null)

      const result = await runtime.runPromiseExit(program)

      if (!cancelled) {
        Exit.match(result, {
          onFailure: (cause) => {
            setError(cause as E)
            setLoading(false)
          },
          onSuccess: (value) => {
            setData(value)
            setLoading(false)
          },
        })
      }
    }

    runProgram()

    return () => {
      cancelled = true
    }
  }, deps)

  return { data, error, loading }
}

export function useEffectStream<A, E>(
  streamProgram: Effect.Effect<A, E>,
  onMessage: (message: A) => void,
  deps: React.DependencyList = []
) {
  const [error, setError] = useState<E | null>(null)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    let fiber: any = null

    const runStream = async () => {
      setConnected(true)

      fiber = await runtime.runFork(
        streamProgram.pipe(
          Effect.catchAll((e) => {
            setError(e as E)
            setConnected(false)
            return Effect.void
          })
        )
      )
    }

    runStream()

    return () => {
      if (fiber) {
        runtime.runSync(fiber.interrupt)
      }
      setConnected(false)
    }
  }, deps)

  return { error, connected }
}
