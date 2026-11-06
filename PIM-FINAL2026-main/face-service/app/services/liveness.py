"""Prova de vida (anti-spoofing).

Provedores:
  none       - NAO verifica nada (uma foto impressa ou na tela passa).
  head_turn  - desafio ativo: o usuario tira uma selfie de frente e outra com a cabeca virada
               para o lado pedido pelo servidor. Mede o giro do rosto (yaw) entre as duas fotos
               e confirma que e a mesma pessoa. Barra foto impressa/imagem parada na tela.
               NAO barra um video gravado do proprio usuario virando a cabeca; para isso seriam
               precisos mais quadros, deteccao de textura/reflexo ou um servico dedicado.
"""
from typing import Optional, Protocol

import numpy as np
from PIL import Image

from ..schemas import LivenessInfo
from .embedder import FaceResult
from .matcher import cosine_similarity


class LivenessProvider(Protocol):
    name: str

    def check(self, img: Image.Image) -> LivenessInfo: ...

    def check_turn(self, front: FaceResult, turned: Optional[FaceResult], challenge: Optional[str]) -> LivenessInfo: ...


class NoLiveness:
    name = "none"

    def check(self, img: Image.Image) -> LivenessInfo:
        return LivenessInfo(checked=False, passed=None, provider=self.name)

    def check_turn(self, front, turned, challenge) -> LivenessInfo:
        return LivenessInfo(checked=False, passed=None, provider=self.name)


class HeadTurnLiveness:
    name = "head_turn"

    def __init__(self, min_yaw_delta: float, same_person_threshold: float, check_direction: bool, left_sign: int) -> None:
        self.min_yaw_delta = min_yaw_delta
        self.same_person_threshold = same_person_threshold
        self.check_direction = check_direction
        self.left_sign = left_sign  # sinal de (yaw_virada - yaw_frente) quando o usuario vira para a ESQUERDA

    def check(self, img: Image.Image) -> LivenessInfo:
        # Uma imagem so nao prova nada: a prova exige as duas selfies (check_turn).
        return LivenessInfo(checked=False, passed=None, provider=self.name)

    def check_turn(self, front: FaceResult, turned: Optional[FaceResult], challenge: Optional[str]) -> LivenessInfo:
        if turned is None or challenge is None:
            return LivenessInfo(checked=False, passed=None, provider=self.name)
        delta = turned.yaw - front.yaw
        same = cosine_similarity(front.embedding, turned.embedding)
        if same < self.same_person_threshold:
            return LivenessInfo(checked=True, passed=False, provider=self.name, reason="different_person", yaw_delta=round(delta, 1))
        if abs(delta) < self.min_yaw_delta:
            return LivenessInfo(checked=True, passed=False, provider=self.name, reason="no_head_turn", yaw_delta=round(delta, 1))
        if self.check_direction:
            expected = self.left_sign if challenge == "left" else -self.left_sign
            if (delta > 0) != (expected > 0):
                return LivenessInfo(checked=True, passed=False, provider=self.name, reason="wrong_direction", yaw_delta=round(delta, 1))
        return LivenessInfo(checked=True, passed=True, provider=self.name, yaw_delta=round(delta, 1))


def build_liveness(provider: str, settings=None) -> LivenessProvider:
    if provider == "none":
        return NoLiveness()
    if provider == "head_turn":
        if settings is None:
            raise ValueError("head_turn precisa das configuracoes")
        return HeadTurnLiveness(settings.liveness_min_yaw_delta, settings.liveness_same_person,
                                settings.liveness_check_direction, settings.liveness_left_sign)
    raise ValueError(f"Provedor de liveness desconhecido: {provider}. Implemente-o em liveness.py")
