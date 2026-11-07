import copy
import re
from typing import List, Dict, Any, Optional, Tuple
from app.schemas.clinical import (
    JointRegion,
    JointSeverity,
    JointRestriction,
    ContraindicatedExercise,
    BiomechanicalSafetyReport,
)

# Base Cinesiológica Determinística de Riscos Articulares e Alternativas Protetoras
CINESIOLOGY_KNOWLEDGE_BASE: Dict[JointRegion, Dict[str, Any]] = {
    JointRegion.SHOULDER: {
        "label": "Ombro & Manguito Rotador",
        "keywords": [
            "ombro", "deltoide", "manguito", "rotador", "supraespinhal",
            "impacto subacromial", "luxacao", "bursite subacromial", "labrum", "slap"
        ],
        "contraindications": [
            {
                "pattern": r"(desenvolvimento.*(nuca|barra)|puxad.*nuca|desenvolvimento militar|militar com barra)",
                "exercise_name": "Desenvolvimento com Barra / Puxada Atrás da Nuca",
                "reason": "Excessiva abdução com rotação externa sob carga axial forçando o ligamento glenoumeral e atritando o tendão supraespinhal.",
                "avoid_vector": "Abdução e rotação externa máxima sob carga",
                "safe_substitute": "Desenvolvimento com Halteres no Plano Escapular (Pegada Neutra)",
            },
            {
                "pattern": r"(remada alta|remada em pe com barra)",
                "exercise_name": "Remada Alta com Barra",
                "reason": "Abdução com rotação interna máxima do úmero, mecanismo clássico do pinçamento subacromial.",
                "avoid_vector": "Abdução combinada com rotação interna do úmero",
                "safe_substitute": "Elevação Lateral no Cabo com Tronco Levemente Inclinado",
            },
            {
                "pattern": r"(paralelas|mergulho em paralelas|dips profundos)",
                "exercise_name": "Mergulho nas Paralelas (Dips)",
                "reason": "Hiperextensão anterior extrema do ombro sob peso corporal tensionando a cápsula anterior e o tendão do bíceps.",
                "avoid_vector": "Extensão do úmero além do plano anatômico",
                "safe_substitute": "Tríceps Corda na Polia Alta ou Supino Fechado no Smith com Trava",
            },
            {
                "pattern": r"(supino reto com barra|supino com barra pesad)",
                "exercise_name": "Supino Reto com Barra Livre",
                "reason": "Pronação fixa que impõe estresse acromioclavicular nos graus finais de descida.",
                "avoid_vector": "Adução horizontal profunda com barra fixa",
                "safe_substitute": "Supino com Halteres Pegada Neutra ou Floor Press",
            },
        ],
        "default_substitute": "Exercício no plano escapular (30° anterior) ou com pegada neutra",
    },
    JointRegion.LUMBAR_SPINE: {
        "label": "Coluna Lombar",
        "keywords": [
            "lombar", "hernia de disco", "espondilolistese", "bico de papagaio",
            "ciatico", "lombalgia", "protrusao discal", "l4", "l5", "s1", "coluna"
        ],
        "contraindications": [
            {
                "pattern": r"(agachamento livre com barra|agachamento barra costas|agachamento pesado)",
                "exercise_name": "Agachamento Livre com Barra nas Costas",
                "reason": "Compressão axial direta das vértebras lombares associada ao torque de flexão anterior da pelve (butt wink).",
                "avoid_vector": "Compressão axial vertical pesada na coluna",
                "safe_substitute": "Agachamento Búlgaro com Halteres ou Leg Press 45° com Lombar Totalmente Apoiada",
            },
            {
                "pattern": r"(levantamento terra|terra com barra|deadlift)",
                "exercise_name": "Levantamento Terra",
                "reason": "Braço de momento excessivo na transição da flexão de quadril elevando a pressão intradiscal lombar.",
                "avoid_vector": "Cisalhamento anterior com carga suspensa",
                "safe_substitute": "Elevação Pélvica com Apoio no Banco ou Extensão de Quadril no Cabo",
            },
            {
                "pattern": r"(stiff com barra|stiff pesado)",
                "exercise_name": "Stiff Livre com Barra",
                "reason": "Grande momento extensor na coluna lombar com potencial de perda de neutralidade espinhal.",
                "avoid_vector": "Flexão anterior de tronco com joelho estendido",
                "safe_substitute": "Mesa Flexora Unilateral ou Stiff Unilateral com Halter (Single Leg RDL)",
            },
            {
                "pattern": r"(remada curvada livre|remada curvada com barra|remada pendlay)",
                "exercise_name": "Remada Curvada com Barra Livre",
                "reason": "Sobrecarga estática isométrica extrema nos paravertebrais lombares em posição flexionada.",
                "avoid_vector": "Sustentação isométrica lombar em semi-flexão",
                "safe_substitute": "Remada no Banco Inclinado com Halteres ou Remada Máquina Cavalinho Apoiada",
            },
        ],
        "default_substitute": "Exercício com tronco apoiado em banco ou apoio externo",
    },
    JointRegion.KNEE: {
        "label": "Joelho & Articulação Patelofemoral",
        "keywords": [
            "joelho", "patela", "patelar", "condromalacia", "menisco",
            "lca", "tendinite patelar", "artrose no joelho", "plica"
        ],
        "contraindications": [
            {
                "pattern": r"(cadeira extensora|extensora)",
                "exercise_name": "Cadeira Extensora em Amplitude Total",
                "reason": "Pico de força de cisalhamento anterior e compressão patelofemoral nos últimos 30 graus de extensão em cadeia aberta.",
                "avoid_vector": "Extensão terminal em cadeia aberta contra resistência externa",
                "safe_substitute": "Agachamento até 90° com Tíbia Vertical ou Cadeira Extensora Isométrica em 60°",
            },
            {
                "pattern": r"(agachamento sissy|sissy squat)",
                "exercise_name": "Sissy Squat",
                "reason": "Projeção extrema do fêmur anteriorizando a tíbia e gerando estresse destrutivo no tendão e cartilagem patelar.",
                "avoid_vector": "Cisalhamento anterior com projeção máxima do joelho",
                "safe_substitute": "Leg Press 45° com Pés Altos na Plataforma",
            },
            {
                "pattern": r"(afundo com salto|lunge saltado|box jump|pliometri)",
                "exercise_name": "Afundo Saltado / Saltos Pliométricos",
                "reason": "Impacto gravitacional brusco com forças reativas de solo absorvidas diretamente pela patela.",
                "avoid_vector": "Impacto balístico e forças reativas de desaceleração",
                "safe_substitute": "Passada / Afundo Estático Controlado com Halteres",
            },
        ],
        "default_substitute": "Exercício de cadeia cinética fechada com pés estáveis e tíbia vertical",
    },
    JointRegion.CERVICAL_SPINE: {
        "label": "Coluna Cervical",
        "keywords": ["cervical", "pescoco", "hernia cervical", "trapezio tenso", "torcicolo", "retificacao cervical"],
        "contraindications": [
            {
                "pattern": r"(puxad.*nuca|desenvolvimento.*nuca)",
                "exercise_name": "Puxada / Desenvolvimento Atrás da Nuca",
                "reason": "Obriga a flexão excessiva e retração da cabeça, comprimindo raízes nervosas cervicais.",
                "avoid_vector": "Retração forçada com hiperextensão cervical",
                "safe_substitute": "Puxada Frontal com Barra Pegada Pronada Aberta",
            },
            {
                "pattern": r"(abdominal tradicional|crunch no chao)",
                "exercise_name": "Abdominal Crunch Tradicional com Mãos na Cabeça",
                "reason": "Tendência de alavanca involuntária no pescoço sobrecarregando os flexores cervicais.",
                "avoid_vector": "Tração anterior da cabeça",
                "safe_substitute": "Prancha Abdominal Isométrica ou Abdominal na Polia com Corda",
            },
        ],
        "default_substitute": "Exercício com alinhamento neutro de cabeça e olhar horizonte",
    },
    JointRegion.HIP: {
        "label": "Quadril & Articulação Coxofemoral",
        "keywords": ["quadril", "femorocetabular", "impacto femoro", "bursite trocanterica", "pubalgia", "labrum quadril"],
        "contraindications": [
            {
                "pattern": r"(agachamento sumo profundo|sumo com barra|sumo com halter profundo)",
                "exercise_name": "Agachamento Sumô com Amplitude Extrema",
                "reason": "Abdução associada à rotação externa extrema em flexão máxima causando atrito fêmoro-acetabular.",
                "avoid_vector": "Abdução com rotação externa profunda",
                "safe_substitute": "Agachamento Padrão na Largura dos Ombros com Amplitude até 90°",
            },
            {
                "pattern": r"(cadeira abdutora.*pesad)",
                "exercise_name": "Cadeira Abdutora com Sobrecarga Máxima",
                "reason": "Compressão e fricção da fáscia lata sobre o trocânter maior favorecendo bursite.",
                "avoid_vector": "Abdução isolada com alavanca lateral rígida",
                "safe_substitute": "Ponte de Glúteos com Mini-Band Leve na Coxa",
            },
        ],
        "default_substitute": "Exercício com alinhamento neutro e afastamento fêmur-quadril padrão",
    },
    JointRegion.WRIST_ELBOW: {
        "label": "Punho & Cotovelo",
        "keywords": ["punho", "cotovelo", "epicondilite", "tunel do carpo", "tendinite no punho", "cotovelo de tenista"],
        "contraindications": [
            {
                "pattern": r"(rosca direta com barra reta|rosca barra reta)",
                "exercise_name": "Rosca Direta com Barra Reta",
                "reason": "Bloqueio do ângulo de carregamento fisiológico do cotovelo gerando torque valgo no epicôndilo medial.",
                "avoid_vector": "Supinação forçada sob eixo linear rígido",
                "safe_substitute": "Rosca com Barra W ou Rosca Martelo com Halteres",
            },
            {
                "pattern": r"(triceps testa com barra reta)",
                "exercise_name": "Tríceps Testa com Barra Reta",
                "reason": "Sobrecarga de cisalhamento posterior no tendão do tríceps distal na inserção do olécrano.",
                "avoid_vector": "Extensão pura de cotovelo com pronação fixa",
                "safe_substitute": "Tríceps Francês no Cabo com Corda ou Tríceps Polia Alta",
            },
        ],
        "default_substitute": "Pegada neutra com halteres ou barras articuladas / barra W",
    },
    JointRegion.ANKLE: {
        "label": "Tornozelo & Fáscia Plantar",
        "keywords": ["tornozelo", "aquiles", "fascite plantar", "entorse", "tendinite calcaneo"],
        "contraindications": [
            {
                "pattern": r"(elevacao de gemeos em pe pesad|panturrilha em pe maquina)",
                "exercise_name": "Gêmeos em Pé com Carga Máxima na Máquina",
                "reason": "Extrema dorsiflexão sob carga axial multiplicando a tração na fáscia plantar e tendão calcâneo.",
                "avoid_vector": "Dorsiflexão máxima sob carga compressiva",
                "safe_substitute": "Gêmeos Sentado (Solear) com Amplitude Controlada",
            },
        ],
        "default_substitute": "Trabalho isométrico ou sem compressão de dorsiflexão máxima",
    },
}


class CinesiologyEngine:
    """
    Motor determinístico O(1) de avaliação biomecânica e segurança cinesiológica.
    Cruza fichas de treino com a matriz de restrições clínicas e gera substituições protetoras.
    """

    @classmethod
    def parse_natural_language_restrictions(cls, text: str) -> List[JointRestriction]:
        """
        Parser semântico O(1) que extrai restrições anatômicas a partir de texto livre.
        Ex: 'Aluno com hérnia de disco lombar e condromalácia no joelho direito'
        """
        if not text or not text.strip():
            return []

        clean_text = text.lower().strip()
        restrictions: List[JointRestriction] = []

        # Detecção de severidade
        is_severe = bool(re.search(r"(grave|cirurgi|hernia|romp|sever|pos-op|protese|agudo)", clean_text))
        severity = JointSeverity.SEVERE if is_severe else JointSeverity.MODERATE

        for joint_region, data in CINESIOLOGY_KNOWLEDGE_BASE.items():
            matched_keywords = [kw for kw in data["keywords"] if kw in clean_text]
            if matched_keywords:
                # Extrai condições correspondentes
                conditions = [kw.capitalize() for kw in matched_keywords[:3]]
                avoid_vectors = [c["avoid_vector"] for c in data["contraindications"]]
                restrictions.append(
                    JointRestriction(
                        joint=joint_region,
                        severity=severity,
                        conditions=conditions,
                        avoid_vectors=avoid_vectors[:2],
                        notes=f"Detectado via anamnese textual: {', '.join(conditions)}",
                    )
                )

        return restrictions

    @classmethod
    def evaluate_workout_safety(
        cls,
        workout_plan: Dict[str, Any],
        restrictions: Optional[List[JointRestriction]] = None,
        raw_restrictions_text: Optional[str] = None,
        auto_apply_substitutes: bool = False,
    ) -> BiomechanicalSafetyReport:
        """
        Avalia se qualquer exercício no workout_plan infringe as restrições articulares.
        Retorna o BiomechanicalSafetyReport detalhado e, se auto_apply_substitutes=True, a ficha adaptada.
        """
        active_restrictions: List[JointRestriction] = []
        if restrictions:
            active_restrictions.extend(restrictions)
        if raw_restrictions_text:
            parsed = cls.parse_natural_language_restrictions(raw_restrictions_text)
            existing_joints = {r.joint for r in active_restrictions}
            for p in parsed:
                if p.joint not in existing_joints:
                    active_restrictions.append(p)

        if not active_restrictions:
            return BiomechanicalSafetyReport(
                is_safe=True,
                overall_risk="safe",
                total_exercises_checked=0,
                contraindications_count=0,
                dangerous_exercises=[],
                protective_recommendation="Nenhuma restrição articular registrada. O treino segue livre de contraindicações.",
                adapted_plan=workout_plan if auto_apply_substitutes else None,
            )

        # Mapa de articulações ativas
        active_joints = {r.joint: r for r in active_restrictions}

        # Extrai exercícios do plano
        splits = workout_plan.get("splits") or []
        dangerous_exercises: List[ContraindicatedExercise] = []
        total_exercises = 0

        # Cópia profunda se for gerar o plano adaptado
        adapted_plan = copy.deepcopy(workout_plan) if auto_apply_substitutes else None

        for split_idx, split in enumerate(splits):
            exercises = split.get("exercises") or []
            total_exercises += len(exercises)

            for ex_idx, ex in enumerate(exercises):
                ex_name = ex.get("name", "").strip()
                if not ex_name:
                    continue

                for joint, restriction in active_joints.items():
                    kb = CINESIOLOGY_KNOWLEDGE_BASE.get(joint)
                    if not kb:
                        continue

                    for rule in kb["contraindications"]:
                        if re.search(rule["pattern"], ex_name, re.IGNORECASE):
                            danger = ContraindicatedExercise(
                                exercise_name=ex_name,
                                joint=joint,
                                severity=restriction.severity,
                                reason=rule["reason"],
                                avoid_vector=rule["avoid_vector"],
                                safe_substitute=rule["safe_substitute"],
                            )
                            # Evita duplicatas se já foi detectado
                            if not any(d.exercise_name == danger.exercise_name and d.joint == danger.joint for d in dangerous_exercises):
                                dangerous_exercises.append(danger)

                            # Aplica a substituição se solicitado
                            if auto_apply_substitutes and adapted_plan:
                                adapted_splits = adapted_plan.get("splits", [])
                                if split_idx < len(adapted_splits):
                                    adapted_exs = adapted_splits[split_idx].get("exercises", [])
                                    if ex_idx < len(adapted_exs):
                                        orig = adapted_exs[ex_idx]
                                        orig["name"] = rule["safe_substitute"]
                                        orig["substitution_vector"] = rule["avoid_vector"]
                                        existing_notes = orig.get("notes", "")
                                        orig["notes"] = (
                                            f"[Blindagem Articular - {kb['label']}]: Substituído de '{ex_name}' "
                                            f"para proteção da articulação. {existing_notes}"
                                        ).strip()

        # Determina o nível de risco geral
        has_severe = any(d.severity == JointSeverity.SEVERE for d in dangerous_exercises)
        if not dangerous_exercises:
            overall_risk = "safe"
            recommendation = "Treino seguro. Todos os exercícios respeitam as articulações mapeadas."
        elif has_severe or len(dangerous_exercises) >= 3:
            overall_risk = "critical_danger"
            recommendation = (
                f"ALERTA CRÍTICO: {len(dangerous_exercises)} exercício(s) contraindicado(s) com alto risco de agravar lesões. "
                "Aplique as substituições protetoras recomendadas antes de liberar a ficha para o aluno."
            )
        else:
            overall_risk = "warning"
            recommendation = (
                f"ATENÇÃO BIOMECÂNICA: {len(dangerous_exercises)} exercício(s) apresentam carga potencialmente estressante. "
                "Recomendamos substituição protetora ou monitoramento rigoroso de amplitude e carga."
            )

        return BiomechanicalSafetyReport(
            is_safe=len(dangerous_exercises) == 0,
            overall_risk=overall_risk,
            total_exercises_checked=total_exercises,
            contraindications_count=len(dangerous_exercises),
            dangerous_exercises=dangerous_exercises,
            protective_recommendation=recommendation,
            adapted_plan=adapted_plan,
        )


cinesiology_engine = CinesiologyEngine()
