import asyncio
import time
import json
import sys
import io

if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from app.services.gemini_service import gemini_service


async def main():
    print("=" * 60)
    print("🚀 TESTE AO VIVO: MOTOR DE INTELIGÊNCIA ARTIFICIAL (GEMINI)")
    print("=" * 60)

    # ---------------------------------------------------------
    # TESTE 1: Prescrição e Periodização de Treino (Treinador)
    # ---------------------------------------------------------
    print("\n[1/2] Testando Geração de Periodização Completa...")
    t0 = time.time()
    try:
        plan = await gemini_service.generate_workout_plan(
            objective="Hipertrofia Muscular",
            training_level="Intermediário",
            days_per_week=4,
            workout_location="Academia completa",
            injuries_or_restrictions="Leve dor no ombro direito (evitar abdução acima de 90° com carga alta)",
            additional_notes="Priorizar peitoral superior e deltoides"
        )
        elapsed_plan = time.time() - t0
        print(f"✅ Periodização gerada com sucesso em {elapsed_plan:.2f}s!")
        print(f"📌 Título: {plan.workout_plan_title}")
        print(f"💡 Diretriz do Treinador: {plan.notes_for_trainer}")
        print(f"📋 Total de Splits: {len(plan.splits)}")
        for split in plan.splits:
            print(f"   - Split {split.split_identifier}: {split.split_name} ({len(split.exercises)} exercícios, ~{split.estimated_duration_min} min)")
            for ex in split.exercises[:2]:  # Mostra os 2 primeiros
                print(f"      • {ex.order}. {ex.name} [{ex.target_muscle_group}] -> {ex.sets}x{ex.reps} (Descanso: {ex.rest_seconds}s)")
    except Exception as e:
        print(f"❌ Erro na geração de treino: {e}")
        return

    # ---------------------------------------------------------
    # TESTE 2: Substituição em Tempo Real no Salão (Aluno)
    # ---------------------------------------------------------
    print("\n[2/2] Testando Substituição Emergencial em Tempo Real (Salão)...")
    t1 = time.time()
    try:
        adaptation = await gemini_service.adapt_exercise(
            current_exercise="Supino Reto com Barra",
            reason="Aparelho Ocupado / Fila",
            workout_location="Academia completa",
            injuries_or_restrictions="Leve dor no ombro direito"
        )
        elapsed_adapt = time.time() - t1
        print(f"✅ Substituição realizada em {elapsed_adapt:.2f}s!")
        print(f"🔄 Exercício Original: {adaptation.original_exercise}")
        print(f"⚡ Variação Sugerida:  {adaptation.adapted_exercise}")
        print(f"📊 Séries/Reps/Descanso: {adaptation.sets}x{adaptation.reps} ({adaptation.rest_seconds}s)")
        print(f"🧬 Racional Biomecânico: {adaptation.biomechanical_rationale}")
        print(f"📝 Notas de Execução:    {adaptation.notes}")
    except Exception as e:
        print(f"❌ Erro na adaptação: {e}")
        return

    print("\n" + "=" * 60)
    print("🎯 TODOS OS TESTES DE IA FORAM CONCLUÍDOS COM SUCESSO!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
